# Infrastructure Addons

Production-grade infrastructure addons for Portfolio platform running on Docker Desktop Kubernetes.

## 📦 Available Addons

| Addon | Purpose | Namespace | Access |
|-------|---------|-----------|--------|
| **OPA Gatekeeper** | Runtime policy enforcement | `gatekeeper-system` | N/A (admission controller) |
| **ArgoCD** | GitOps continuous deployment | `argocd` | `kubectl port-forward -n argocd svc/argocd-server 8080:443` |
| **LocalStack** | Local AWS service emulation | `localstack` | http://localhost:4566 |
| **Prometheus** | Metrics collection & monitoring | `monitoring` | `kubectl port-forward -n monitoring svc/prometheus-server 9090:80` |
| **Grafana** | Metrics visualization & dashboards | `monitoring` | `kubectl port-forward -n monitoring svc/grafana 3000:80` |

---

## 🚀 Quick Start

### Install All Addons (Recommended)

```bash
cd infrastructure/addons
./install-all.sh
```

This will install all addons in the correct order with dependency handling.

### Install Individual Addons

```bash
# Install specific addon
cd infrastructure/addons/<addon-name>
./install.sh

# Examples:
cd infrastructure/addons/opa-gatekeeper && ./install.sh
cd infrastructure/addons/argocd && ./install.sh
cd infrastructure/addons/localstack && ./install.sh
cd infrastructure/addons/prometheus && ./install.sh
cd infrastructure/addons/grafana && ./install.sh
```

---

## 📋 Prerequisites

- Docker Desktop with Kubernetes enabled
- kubectl configured and connected to Docker Desktop cluster
- Helm 3.x installed (for Prometheus/Grafana)
- At least 8GB RAM allocated to Docker Desktop

---

## 🛠️ Addon Details

### 1. OPA Gatekeeper

**What:** Kubernetes admission controller for policy enforcement
**Why:** Runtime validation of Kubernetes resources against policies
**Used For:** Enforcing security policies, compliance, best practices

**Installation:**
```bash
cd infrastructure/addons/opa-gatekeeper
./install.sh
```

**Verification:**
```bash
kubectl get pods -n gatekeeper-system
kubectl get constrainttemplates
```

**Uninstall:**
```bash
kubectl delete -f manifests/gatekeeper.yaml
```

---

### 2. ArgoCD

**What:** GitOps continuous delivery tool for Kubernetes
**Why:** Automated deployments from Git repositories
**Used For:** Managing Portfolio Method 3 (Helm + ArgoCD) deployment

**Installation:**
```bash
cd infrastructure/addons/argocd
./install.sh
```

**Access UI:**
```bash
# Port forward to access UI
kubectl port-forward -n argocd svc/argocd-server 8080:443

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Login: admin / <password from above>
# URL: https://localhost:8080
```

**Verification:**
```bash
kubectl get pods -n argocd
kubectl get applications -n argocd
```

**Uninstall:**
```bash
kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl delete namespace argocd
```

---

### 3. LocalStack

**What:** Local AWS cloud stack emulator
**Why:** Test AWS services (S3, DynamoDB, SQS) locally without costs
**Used For:** Portfolio Method 2 (Terraform + LocalStack) deployment

**Installation:**
```bash
cd infrastructure/addons/localstack
./install.sh
```

**Access:**
- Endpoint: `http://localhost:4566`
- Dashboard: `http://localhost:4566/_localstack/health`

**AWS CLI Configuration:**
```bash
# Use LocalStack endpoint
export AWS_ENDPOINT_URL=http://localhost:4566
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1

# Test S3
aws --endpoint-url=http://localhost:4566 s3 ls
```

**Verification:**
```bash
kubectl get pods -n localstack
curl http://localhost:4566/_localstack/health
```

**Uninstall:**
```bash
kubectl delete -f manifests/
kubectl delete namespace localstack
```

---

### 4. Prometheus

**What:** Time-series metrics database and monitoring system
**Why:** Collect metrics from Kubernetes and applications
**Used For:** Monitoring Portfolio API performance, K8s cluster health

**Installation:**
```bash
cd infrastructure/addons/prometheus
./install.sh
```

**Access:**
```bash
# Port forward Prometheus UI
kubectl port-forward -n monitoring svc/prometheus-server 9090:80

# Open: http://localhost:9090
```

**Useful Queries:**
```promql
# API request rate
rate(http_requests_total[5m])

# Pod CPU usage
container_cpu_usage_seconds_total{namespace="portfolio"}

# Memory usage
container_memory_usage_bytes{namespace="portfolio"}
```

**Verification:**
```bash
kubectl get pods -n monitoring | grep prometheus
curl http://localhost:9090/api/v1/status/config
```

**Uninstall:**
```bash
helm uninstall prometheus -n monitoring
```

---

### 5. Grafana

**What:** Metrics visualization and dashboards
**Why:** Beautiful dashboards for Prometheus metrics
**Used For:** Visualizing Portfolio performance, Kubernetes metrics

**Installation:**
```bash
cd infrastructure/addons/grafana
./install.sh
```

**Access:**
```bash
# Port forward Grafana UI
kubectl port-forward -n monitoring svc/grafana 3000:80

# Default credentials:
# Username: admin
# Password: Get from secret or use 'admin' (change on first login)
kubectl get secret -n monitoring grafana -o jsonpath="{.data.admin-password}" | base64 -d
```

**Pre-configured Dashboards:**
- Kubernetes Cluster Monitoring
- Portfolio API Metrics
- Node Exporter Full
- Pod Resource Usage

**Verification:**
```bash
kubectl get pods -n monitoring | grep grafana
curl http://localhost:3000/api/health
```

**Uninstall:**
```bash
helm uninstall grafana -n monitoring
```

---

## 🔄 Installation Order

The `install-all.sh` script installs addons in this order:

1. **OPA Gatekeeper** (no dependencies)
2. **LocalStack** (no dependencies)
3. **Prometheus** (monitoring foundation)
4. **Grafana** (depends on Prometheus data source)
5. **ArgoCD** (can reference all other addons)

---

## 📊 Resource Requirements

| Addon | CPU Request | Memory Request | CPU Limit | Memory Limit |
|-------|-------------|----------------|-----------|--------------|
| OPA Gatekeeper | 100m | 256Mi | 1000m | 512Mi |
| ArgoCD | 250m | 256Mi | 500m | 512Mi |
| LocalStack | 500m | 1Gi | 2000m | 2Gi |
| Prometheus | 500m | 2Gi | 1000m | 4Gi |
| Grafana | 100m | 256Mi | 200m | 512Mi |
| **Total** | **1.45 CPU** | **3.75Gi RAM** | **4.7 CPU** | **7.5Gi RAM** |

**Recommendation:** Allocate at least 8GB RAM to Docker Desktop.

---

## 🧪 Testing

After installation, verify all addons are running:

```bash
# Check all addon namespaces
kubectl get pods -n gatekeeper-system
kubectl get pods -n argocd
kubectl get pods -n localstack
kubectl get pods -n monitoring

# Check addon health
./test-addons.sh
```

---

## 🗑️ Uninstall

### Uninstall All Addons
```bash
cd infrastructure/addons
./uninstall-all.sh
```

### Uninstall Individual Addon
```bash
cd infrastructure/addons/<addon-name>
./uninstall.sh
```

---

## 🔐 Security Notes

- **ArgoCD**: Change default admin password immediately after installation
- **Grafana**: Change default admin password on first login
- **LocalStack**: Only for local development, DO NOT expose to internet
- **Prometheus**: Contains cluster metrics, protect access in production

---

## 📚 Additional Resources

- [OPA Gatekeeper Docs](https://open-policy-agent.github.io/gatekeeper/)
- [ArgoCD Docs](https://argo-cd.readthedocs.io/)
- [LocalStack Docs](https://docs.localstack.cloud/)
- [Prometheus Docs](https://prometheus.io/docs/)
- [Grafana Docs](https://grafana.com/docs/)

---

**Last Updated:** November 14, 2025
**Maintained By:** Jimmie Coleman - Portfolio Platform