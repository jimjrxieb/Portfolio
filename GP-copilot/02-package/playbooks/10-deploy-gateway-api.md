# Playbook 09 — Deploy Gateway API

> Replace legacy Ingress with Gateway API for role-separated traffic routing.
> Platform team owns the Gateway (TLS, ports). App teams own HTTPRoutes (paths, backends).

---

## Why Gateway API Over Ingress

| Feature | Ingress | Gateway API |
|---------|---------|-------------|
| Role separation | No — one resource controls everything | Yes — GatewayClass / Gateway / HTTPRoute |
| Canary / traffic splitting | Not native | Native weight-based routing |
| Cross-namespace routing | Not supported | ReferenceGrant |
| TLS per listener | Limited | Full control per listener |
| Standard status | Beta/frozen | GA (v1.2+) |

**CNPA exam**: When asked "route HTTP traffic" or "role separation for routing" → Gateway API.

---

## Prerequisites

- Cluster running (02 hardening complete)
- `kubectl`, `helm` installed (`tools/hardening/install-scanners.sh`)
- One of: Envoy Gateway, Cilium, Istio, or nginx-gateway-fabric

---

## Step 1: Install Gateway API + Controller

```bash
PKG=~/GP-copilot/GP-CONSULTING/02-CLUSTER-HARDENING

# Automated (installs CRDs + controller + GatewayClass)
bash $PKG/tools/platform/setup-gateway-api.sh --controller envoy

# Or dry-run first
bash $PKG/tools/platform/setup-gateway-api.sh --controller envoy --dry-run
```

**Controller options:**

| Controller | Best for | Install size |
|-----------|----------|-------------|
| `envoy` | Greenfield clusters, lightweight | ~100Mi |
| `cilium` | Clusters already using Cilium CNI | Built-in |
| `istio` | Clusters already running Istio mesh | Built-in |
| `nginx` | Teams familiar with nginx config | ~50Mi |

### Verify

```bash
kubectl get gatewayclass gp-gateway
# ACCEPTED should be True

kubectl get pods -n envoy-gateway-system   # (or your controller namespace)
# All pods Running
```

---

## Step 2: Deploy a Gateway

Edit the template with your values:

```bash
# Copy and customize
cp $PKG/templates/gateway-api/gateway.yaml /tmp/my-gateway.yaml

# Replace placeholders
sed -i \
  -e 's|<APP_NAME>|myapp|g' \
  -e 's|<NAMESPACE>|myapp|g' \
  -e 's|<DOMAIN>|myapp.example.com|g' \
  -e 's|<TLS_SECRET>|myapp-tls|g' \
  -e 's|<GATEWAY_CLASS_NAME>|gp-gateway|g' \
  /tmp/my-gateway.yaml

kubectl apply -f /tmp/my-gateway.yaml
```

### Create TLS secret (if not using cert-manager)

```bash
kubectl create secret tls myapp-tls \
  --cert=cert.pem --key=key.pem \
  -n myapp
```

### Verify

```bash
kubectl get gateway -n myapp
# PROGRAMMED should be True

kubectl describe gateway myapp-gateway -n myapp
# Check listeners are attached and have valid addresses
```

---

## Step 3: Create HTTPRoutes

```bash
# Copy and customize standard routes
cp $PKG/templates/gateway-api/httproute.yaml /tmp/my-routes.yaml

sed -i \
  -e 's|<APP_NAME>|myapp|g' \
  -e 's|<NAMESPACE>|myapp|g' \
  -e 's|<API_SERVICE>|myapp-api|g' \
  -e 's|<API_PORT>|8080|g' \
  -e 's|<UI_SERVICE>|myapp-ui|g' \
  -e 's|<UI_PORT>|3000|g' \
  /tmp/my-routes.yaml

kubectl apply -f /tmp/my-routes.yaml
```

### Test

```bash
# Get Gateway external IP
GW_IP=$(kubectl get gateway myapp-gateway -n myapp -o jsonpath='{.status.addresses[0].value}')

# Test HTTPS redirect
curl -I http://${GW_IP}/ -H "Host: myapp.example.com"
# Should return 301 → https://

# Test API route
curl -k https://${GW_IP}/api/health -H "Host: myapp.example.com"

# Test UI route
curl -k https://${GW_IP}/ -H "Host: myapp.example.com"
```

---

## Step 4: Canary Deployment (Progressive Delivery)

Deploy a canary version of your service:

```bash
# 1. Deploy canary Service (same app, new image tag)
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: myapp-api-canary
  namespace: myapp
spec:
  selector:
    app: myapp-api
    track: canary
  ports:
    - port: 8080
EOF

# 2. Apply canary HTTPRoute (90/10 split)
cp $PKG/templates/gateway-api/httproute-canary.yaml /tmp/my-canary.yaml

sed -i \
  -e 's|<APP_NAME>|myapp|g' \
  -e 's|<NAMESPACE>|myapp|g' \
  -e 's|<STABLE_SERVICE>|myapp-api|g' \
  -e 's|<CANARY_SERVICE>|myapp-api-canary|g' \
  -e 's|<PORT>|8080|g' \
  /tmp/my-canary.yaml

kubectl apply -f /tmp/my-canary.yaml

# 3. Test with header override (hits canary 100%)
curl -k https://${GW_IP}/api/health \
  -H "Host: myapp.example.com" \
  -H "x-canary: true"

# 4. Shift traffic: 50/50 → 0/100 as confidence grows
#    Edit weights in the HTTPRoute and re-apply
```

---

## Step 5: Enforce TLS Policy

```bash
# Deploy Kyverno policy (audit mode by default)
kubectl apply -f $PKG/templates/policies/kyverno/require-gateway-tls.yaml

# Check for violations
kubectl get policyreport -A | grep gateway

# Add conftest to CI
# Copy gateway-api.rego to client repo
cp $PKG/templates/policies/conftest/gateway-api.rego /path/to/client/policies/
```

---

## Cross-Namespace Routing

If the TLS secret lives in a different namespace (e.g., cert-manager creates it in `cert-manager` namespace):

```bash
cp $PKG/templates/gateway-api/reference-grant.yaml /tmp/ref-grant.yaml

sed -i \
  -e 's|<SECRET_NAMESPACE>|cert-manager|g' \
  -e 's|<GATEWAY_NAMESPACE>|myapp|g' \
  /tmp/ref-grant.yaml

kubectl apply -f /tmp/ref-grant.yaml
```

---

## Troubleshooting

### Gateway stuck in "Not Programmed"

```bash
kubectl describe gateway myapp-gateway -n myapp
# Check Events for controller errors
# Verify GatewayClass is Accepted: kubectl get gatewayclass
```

### HTTPRoute not attaching

```bash
kubectl describe httproute myapp-api -n myapp
# Check parentRef matches Gateway name
# Check allowedRoutes.namespaces.from in Gateway
```

### TLS certificate issues

```bash
kubectl get secret myapp-tls -n myapp -o yaml
# Verify tls.crt and tls.key exist
# If using cert-manager: kubectl get certificate -n myapp
```

---

## Templates Reference

| File | What | Who owns it |
|------|------|-------------|
| `gateway-class.yaml` | Controller selection | Infra team |
| `gateway.yaml` | Listeners, TLS, ports | Platform team |
| `httproute.yaml` | Path routing to backends | App team |
| `httproute-canary.yaml` | Weight-based canary split | App team |
| `reference-grant.yaml` | Cross-namespace secret access | Platform team |
| `require-gateway-tls.yaml` | Kyverno: enforce TLS on 443 | Platform team |
| `gateway-api.rego` | Conftest: CI validation | Platform team |

---

*Ghost Protocol — Gateway API (CKA + CNPA)*
