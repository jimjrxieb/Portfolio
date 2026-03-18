# CKAD Domain 4: Services and Networking (20%)

Demonstrate basic understanding of NetworkPolicies. Provide and troubleshoot access to applications via services. Use Ingress rules to expose applications.

## CKAD Exam Quick Reference

### Service Types
```bash
# ClusterIP (internal only — default)
kubectl expose deployment web --port=80 --target-port=8080
kubectl expose deployment web --port=80 --target-port=8080 --type=ClusterIP

# NodePort (external via node IP:port)
kubectl expose deployment web --port=80 --target-port=8080 --type=NodePort

# LoadBalancer (cloud provider external IP)
kubectl expose deployment web --port=80 --target-port=8080 --type=LoadBalancer

# ExternalName (DNS alias)
kubectl create service externalname ext-db --external-name=db.external.com
```

### Service YAML
```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-svc
spec:
  type: ClusterIP
  selector:
    app: web              # Must match pod labels
  ports:
  - name: http
    port: 80              # Service port
    targetPort: 8080      # Container port
    protocol: TCP
  - name: metrics
    port: 9090
    targetPort: 9090
```

### Headless Service (StatefulSet DNS)
```yaml
apiVersion: v1
kind: Service
metadata:
  name: db-headless
spec:
  clusterIP: None         # Headless — no ClusterIP
  selector:
    app: db
  ports:
  - port: 5432
# DNS: <pod-name>.db-headless.<namespace>.svc.cluster.local
```

### DNS Resolution
```bash
# Service DNS
# <service>.<namespace>.svc.cluster.local
# e.g., web-svc.default.svc.cluster.local

# Short form (same namespace)
# web-svc

# Test DNS
kubectl run dns-test --image=busybox --rm -it -- nslookup web-svc
kubectl run dns-test --image=busybox --rm -it -- nslookup web-svc.default.svc.cluster.local
```

### Ingress
```bash
# Imperative
kubectl create ingress web-ingress --rule="app.example.com/=web-svc:80"
kubectl create ingress web-ingress --rule="app.example.com/api*=api-svc:80"
```

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$1
spec:
  ingressClassName: nginx
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /api(/|$)(.*)
        pathType: ImplementationSpecific
        backend:
          service:
            name: api-svc
            port:
              number: 80
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend-svc
            port:
              number: 80
  tls:
  - hosts:
    - app.example.com
    secretName: tls-secret
```

### NetworkPolicies (CKAD level)
```yaml
# Default deny all ingress
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
  namespace: app-ns
spec:
  podSelector: {}
  policyTypes:
  - Ingress

---
# Allow specific pod-to-pod
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-api-to-db
  namespace: app-ns
spec:
  podSelector:
    matchLabels:
      app: db
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: api
    ports:
    - port: 5432

---
# Allow from specific namespace
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-monitoring
  namespace: app-ns
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: monitoring
    ports:
    - port: 9090

---
# Egress — allow only DNS and specific service
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: restrict-egress
  namespace: app-ns
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: db
    ports:
    - port: 5432
  - ports:            # DNS
    - port: 53
      protocol: UDP
    - port: 53
      protocol: TCP
```

### Troubleshooting Services
```bash
# 1. Check endpoints (most common issue)
kubectl get endpoints web-svc
# Empty endpoints? Selector doesn't match any pods.

# 2. Verify selector matches
kubectl get pods -l app=web
kubectl get svc web-svc -o jsonpath='{.spec.selector}'

# 3. Check target port
kubectl get svc web-svc -o jsonpath='{.spec.ports[0].targetPort}'
# Must match container port

# 4. Test from inside cluster
kubectl run test --image=busybox --rm -it -- wget -qO- http://web-svc:80

# 5. Check pod is actually listening
kubectl exec web-pod -- netstat -tlnp
```

## Cross-Reference to GP-CONSULTING

| Need | Location |
|------|----------|
| NetworkPolicy templates | `04-KUBESTER/templates/quick-ref/networkpolicy-default-deny.yaml` |
| Full NetworkPolicy remediation | `02-CLUSTER-HARDENING/templates/remediation/network-policies.yaml` |
| Generate NetworkPolicy | `03-DEPLOY-RUNTIME/responders/generate-networkpolicy.sh` |
| Gateway API (next-gen Ingress) | `02-CLUSTER-HARDENING/templates/gateway-api/` |
| Fix NodePort to ClusterIP | `02-CLUSTER-HARDENING/tools/hardening/fix-nodeport.sh` |
| Network coverage watcher | `03-DEPLOY-RUNTIME/watchers/watch-network-coverage.sh` |

## Practice Scenarios

1. **ClusterIP + Ingress**: Deploy app, expose as ClusterIP, create Ingress with path routing
2. **Multi-port service**: Create service exposing both HTTP (80) and metrics (9090)
3. **NetworkPolicy**: Default deny namespace, then allow only frontend -> backend -> db chain
4. **DNS debugging**: Service exists but pod can't reach it — diagnose selector/port mismatch
5. **Headless service**: Deploy StatefulSet with headless service, resolve individual pod DNS
6. **Cross-namespace**: Allow monitoring namespace to scrape metrics from app namespace
