# Network Segmentation — FedRAMP SC-7

## The Problem

No NetworkPolicy = flat network. Any compromised pod can reach any other pod.
SC-7 (Boundary Protection) requires explicit network boundaries.

## Quick Diagnosis

```bash
# Namespaces without any NetworkPolicy
for ns in $(kubectl get ns -o name | cut -d/ -f2); do
  count=$(kubectl get networkpolicy -n "$ns" --no-headers 2>/dev/null | wc -l)
  [ "$count" -eq 0 ] && echo "MISSING NetworkPolicy: $ns"
done

# Services exposed via NodePort (should be ClusterIP + Ingress)
kubectl get svc -A -o json | jq -r '
  .items[] | select(.spec.type == "NodePort") |
  "\(.metadata.namespace)/\(.metadata.name) type=NodePort"
'

# Pods without network isolation
kubectl get pods -A -o wide --show-labels | grep -v "network-policy"
```

## Fix: Default-Deny in Every Namespace

Start with deny-all, then open only what's needed:

```yaml
# default-deny-all.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: {{NAMESPACE}}
spec:
  podSelector: {}  # Applies to ALL pods in namespace
  policyTypes:
    - Ingress
    - Egress
```

Apply:
```bash
kubectl apply -f default-deny-all.yaml
```

## Fix: Allow Specific Traffic

**Frontend → Backend API:**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-api
  namespace: {{NAMESPACE}}
spec:
  podSelector:
    matchLabels:
      app: {{APP_NAME}}-api
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: {{APP_NAME}}-frontend
      ports:
        - protocol: TCP
          port: 8080
```

**Backend API → Database:**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-api-to-db
  namespace: {{NAMESPACE}}
spec:
  podSelector:
    matchLabels:
      app: {{DB_NAME}}
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: {{APP_NAME}}-api
      ports:
        - protocol: TCP
          port: {{DB_PORT}}
```

**Allow DNS egress (required for service discovery):**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns-egress
  namespace: {{NAMESPACE}}
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
```

## Fix: Replace NodePort with ClusterIP + Ingress

```yaml
# Change service type
apiVersion: v1
kind: Service
metadata:
  name: {{APP_NAME}}
  namespace: {{NAMESPACE}}
spec:
  type: ClusterIP  # NOT NodePort
  selector:
    app: {{APP_NAME}}
  ports:
    - port: 80
      targetPort: 8080
---
# Expose via Ingress with TLS
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{APP_NAME}}-ingress
  namespace: {{NAMESPACE}}
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  tls:
    - hosts:
        - {{APP_DOMAIN}}
      secretName: {{APP_NAME}}-tls
  rules:
    - host: {{APP_DOMAIN}}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: {{APP_NAME}}
                port:
                  number: 80
```

## Full Templates

See `remediation-templates/network-policies.yaml` and `kubernetes-templates/networkpolicy.yaml`.

## Evidence for 3PAO

- [ ] `kubectl get networkpolicy -A` showing policies in all namespaces
- [ ] Network flow diagram (what talks to what)
- [ ] No NodePort services
- [ ] Ingress with TLS termination
- [ ] Conftest policy check passing

## Remediation Priority: D — Auto-Remediate

NetworkPolicy creation is pattern-based — automated tooling auto-generates from pod labels.
