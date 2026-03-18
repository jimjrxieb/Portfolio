# CKA Domain 3: Services & Networking (20%)

Understand host networking configuration on the cluster nodes. Understand connectivity between Pods. Understand ClusterIP, NodePort, LoadBalancer service types and endpoints. Know how to use Ingress controllers and Ingress resources. Know how to configure and use CoreDNS. Choose an appropriate container network interface plugin.

## CKA Exam Quick Reference

### Services
```bash
# ClusterIP (default — internal only)
kubectl expose deployment nginx --port=80 --target-port=8080

# NodePort (external via node IP)
kubectl expose deployment nginx --port=80 --target-port=8080 --type=NodePort

# LoadBalancer (cloud provider)
kubectl expose deployment nginx --port=80 --target-port=8080 --type=LoadBalancer

# Headless service (DNS only, no ClusterIP)
kubectl create service clusterip my-svc --clusterip="None"
```

### Service YAML
```yaml
apiVersion: v1
kind: Service
metadata:
  name: backend-svc
spec:
  type: ClusterIP
  selector:
    app: backend
  ports:
  - port: 80
    targetPort: 8080
    protocol: TCP
```

### DNS
```bash
# Pod DNS resolution
# <service-name>.<namespace>.svc.cluster.local
# e.g., backend-svc.app-ns.svc.cluster.local

# Test from a pod
kubectl run test --image=busybox --rm -it -- nslookup backend-svc.app-ns.svc.cluster.local

# Debug CoreDNS
kubectl -n kube-system get pods -l k8s-app=kube-dns
kubectl -n kube-system logs -l k8s-app=kube-dns

# CoreDNS ConfigMap
kubectl -n kube-system get configmap coredns -o yaml
```

### Ingress
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /api
        pathType: Prefix
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
```

### Network Policies
```yaml
# Default deny all in namespace
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: app-ns
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress

---
# Allow specific ingress
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend
  namespace: app-ns
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - port: 8080

---
# Allow DNS egress (critical — pods need this)
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: app-ns
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector: {}
    ports:
    - port: 53
      protocol: UDP
    - port: 53
      protocol: TCP
```

### CNI Plugin
```bash
# Check installed CNI
ls /etc/cni/net.d/
cat /etc/cni/net.d/*.conflist | jq .name

# Install Calico (most common in exams)
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/calico.yaml

# Install Flannel
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

# Verify CNI pods
kubectl get pods -n kube-system | grep -E 'calico|flannel|cilium|weave'
```

### Gateway API (next-gen Ingress)
```bash
# See full templates at:
# 02-CLUSTER-HARDENING/templates/gateway-api/
# Setup script:
# 02-CLUSTER-HARDENING/tools/platform/setup-gateway-api.sh
```

## Cross-Reference to GP-CONSULTING

| Need | Location |
|------|----------|
| NetworkPolicy templates | `02-CLUSTER-HARDENING/templates/remediation/network-policies.yaml` |
| Generate NetworkPolicy | `03-DEPLOY-RUNTIME/responders/generate-networkpolicy.sh` |
| Network coverage watcher | `03-DEPLOY-RUNTIME/watchers/watch-network-coverage.sh` |
| Dataplane health watcher | `03-DEPLOY-RUNTIME/watchers/watch-dataplane.sh` |
| Gateway API templates | `02-CLUSTER-HARDENING/templates/gateway-api/` |
| Gateway API setup | `02-CLUSTER-HARDENING/tools/platform/setup-gateway-api.sh` |
| Service mesh deploy | `03-DEPLOY-RUNTIME/tools/deploy-service-mesh.sh` |
| Fix NodePort services | `02-CLUSTER-HARDENING/tools/hardening/fix-nodeport.sh` |

## Practice Scenarios

1. **Services**: Create ClusterIP, NodePort, and headless services for a 3-tier app
2. **DNS debugging**: Fix a pod that can't resolve a service name
3. **Ingress**: Set up path-based routing for 3 services behind one hostname
4. **NetworkPolicy**: Implement default-deny + allow-specific for a microservices app
5. **CNI install**: Bootstrap a cluster, install Calico, verify pod networking works
6. **Troubleshoot**: Fix a broken service (wrong selector, wrong port, missing endpoints)
