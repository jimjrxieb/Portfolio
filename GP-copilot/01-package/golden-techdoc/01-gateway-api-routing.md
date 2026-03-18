# 01 — Gateway API Routing

Expose your app to the internet using standard Kubernetes Gateway API.
No Traefik CRDs, no nginx annotations, no vendor lock-in.

## Prerequisites (Platform Engineer Provides)

- GatewayClass `gp-gateway` exists on the cluster
- Gateway API CRDs installed
- Cloudflare tunnel or LoadBalancer routing traffic to the cluster

## Step 1: Create a Gateway (Your Namespace)

The Gateway defines what hostname and port your app listens on.
Platform team controls the GatewayClass — you just reference it.

```yaml
# templates/gateway.yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: {{ include "myapp.fullname" . }}-gateway
  labels:
    {{- include "myapp.labels" . | nindent 4 }}
    control: SC-7
spec:
  gatewayClassName: {{ .Values.gateway.className }}   # Platform provides this
  listeners:
    - name: http
      protocol: HTTP
      port: {{ .Values.gateway.listenerPort }}        # Must match ingress controller entrypoint
      hostname: {{ .Values.gateway.host | quote }}
      allowedRoutes:
        namespaces:
          from: Same    # Only HTTPRoutes in YOUR namespace can attach
```

### Values

```yaml
gateway:
  enabled: true
  className: gp-gateway         # Ask your platform engineer
  host: myapp.example.com
  listenerPort: 8000            # Ask your platform engineer (Traefik web=8000)
  annotations: {}
```

> **Why port 8000 and not 80?** The ingress controller (Traefik) listens internally
> on port 8000 (`web` entrypoint). The LoadBalancer Service maps external port 80
> to internal port 8000. Your Gateway listener must match the internal port.
> Your platform engineer will tell you the correct value.

---

## Step 2: Create HTTPRoutes

HTTPRoutes define path-based routing to your services.

### Simple App (Single Service)

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: {{ include "myapp.fullname" . }}-route
  labels:
    {{- include "myapp.labels" . | nindent 4 }}
spec:
  parentRefs:
    - name: {{ include "myapp.fullname" . }}-gateway
      sectionName: http
  hostnames:
    - {{ .Values.gateway.host | quote }}
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: {{ include "myapp.fullname" . }}
          port: {{ .Values.service.port }}
```

### API + Frontend (Path-Based Routing)

```yaml
---
# API route: /api/* → strip prefix → api service
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: {{ include "myapp.fullname" . }}-api
spec:
  parentRefs:
    - name: {{ include "myapp.fullname" . }}-gateway
      sectionName: http
  hostnames:
    - {{ .Values.gateway.host | quote }}
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /api
      filters:
        - type: URLRewrite
          urlRewrite:
            path:
              type: ReplacePrefixMatch
              replacePrefixMatch: /
      backendRefs:
        - name: {{ include "myapp.fullname" . }}-api
          port: {{ .Values.api.service.port }}
---
# UI route: /* → frontend service (catch-all)
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: {{ include "myapp.fullname" . }}-ui
spec:
  parentRefs:
    - name: {{ include "myapp.fullname" . }}-gateway
      sectionName: http
  hostnames:
    - {{ .Values.gateway.host | quote }}
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: {{ include "myapp.fullname" . }}-ui
          port: {{ .Values.ui.service.port }}
```

---

## Step 3: Prefix Stripping (Replaces Traefik Middleware)

If your API lives at `/api` externally but expects `/` internally, use the
`URLRewrite` filter. This replaces Traefik's `stripPrefix` middleware with
standard Gateway API — no vendor CRDs needed.

```yaml
filters:
  - type: URLRewrite
    urlRewrite:
      path:
        type: ReplacePrefixMatch
        replacePrefixMatch: /
```

**What this does:**
- Browser calls `https://myapp.com/api/health`
- Gateway strips `/api` → forwards `/health` to your backend
- Your FastAPI/Express app handles `/health` (not `/api/health`)

---

## Migrating from Ingress

If your chart currently uses `networking.k8s.io/v1 Ingress`:

| Old (Ingress) | New (Gateway API) |
|---|---|
| `kind: Ingress` | `kind: Gateway` + `kind: HTTPRoute` |
| `ingressClassName: traefik` | `gatewayClassName: gp-gateway` |
| `annotations: traefik.../middlewares` | `filters: [URLRewrite]` |
| `traefik.io/v1alpha1 Middleware` | Delete — use HTTPRoute filters |
| `tls.secretName` | Gateway listener `tls.certificateRefs` (platform manages) |
| `rules[].http.paths[]` | HTTPRoute `rules[].matches[]` + `backendRefs[]` |

### Checklist

- [ ] Replace `ingress.yaml` with `gateway.yaml` + `httproute.yaml`
- [ ] Delete `middleware.yaml` (Traefik CRD)
- [ ] Update `values.yaml`: `ingress` section → `gateway` section
- [ ] Remove any `traefik.io` annotations
- [ ] `helm template` renders clean (no Traefik CRD references)
- [ ] Bump chart version

---

## Validation

```bash
# Render and verify no vendor CRDs
helm template myapp ./charts/myapp/ | grep -i "traefik\|apiVersion: traefik"
# Should return nothing

# After deploy — check Gateway accepted
kubectl get gateway -n mynamespace
# NAME                  CLASS        ADDRESS   PROGRAMMED   AGE
# myapp-gateway         gp-gateway             True         1m

# Check HTTPRoutes attached
kubectl get httproute -n mynamespace
# NAME         HOSTNAMES              AGE
# myapp-api    ["myapp.example.com"]  1m
# myapp-ui     ["myapp.example.com"]  1m

# Test routing
curl -H 'Host: myapp.example.com' http://<cluster-ip>:80/
curl -H 'Host: myapp.example.com' http://<cluster-ip>:80/api/health
```

---

## Common Mistakes

1. **Wrong listener port** — Must match the ingress controller's entrypoint port (not the external LB port)
2. **Missing `sectionName`** — If your Gateway has multiple listeners, HTTPRoute must specify which one
3. **Forgot `hostnames`** — HTTPRoute without `hostnames` matches everything (too broad)
4. **Wildcard hostnames** — Kyverno policy blocks `*` hostnames. Use explicit FQDNs
5. **Using NodePort/LoadBalancer** — Always use ClusterIP. Gateway handles external access
