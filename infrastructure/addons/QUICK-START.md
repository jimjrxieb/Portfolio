# Infrastructure Addons - Quick Start Guide

Get all infrastructure addons running in 5 minutes!

## ⚡ TL;DR - Install Everything

```bash
cd /home/jimmie/linkops-industries/Portfolio/infrastructure/addons
./install-all.sh
```

That's it! The script will:
1. Check prerequisites (kubectl, helm)
2. Install all 5 addons in dependency order
3. Wait for each to be ready
4. Display access instructions

---

## 📦 What Gets Installed

| Addon | Purpose | Namespace |
|-------|---------|-----------|
| **OPA Gatekeeper** | Policy enforcement | `gatekeeper-system` |
| **LocalStack** | Local AWS (S3, DynamoDB, SQS) | `localstack` |
| **Prometheus** | Metrics collection | `monitoring` |
| **Grafana** | Dashboards & visualization | `monitoring` |
| **ArgoCD** | GitOps deployment | `argocd` |

---

## 🚀 Installation

### Option 1: Install All (Recommended)

```bash
cd infrastructure/addons
./install-all.sh
```

**Time:** ~5-10 minutes (depending on image pulls)

### Option 2: Install Individually

```bash
# Install specific addon
cd infrastructure/addons/<addon-name>
./install.sh

# Examples:
cd infrastructure/addons/localstack && ./install.sh
cd infrastructure/addons/argocd && ./install.sh
```

---

## 🔍 Verify Installation

```bash
cd infrastructure/addons
./test-addons.sh
```

This checks:
- All namespaces exist
- All pods are running
- Services are reachable

**Expected Output:**
```
🎉 All addons are healthy! (0 failures)
```

---

## 🌐 Access Addons

### LocalStack (AWS Emulator)

```bash
# Already exposed on localhost
curl http://localhost:4566/_localstack/health

# Test S3
export AWS_ENDPOINT_URL=http://localhost:4566
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
aws --endpoint-url=http://localhost:4566 s3 mb s3://test-bucket
aws --endpoint-url=http://localhost:4566 s3 ls
```

**No port forward needed!** ✅

---

### Prometheus (Metrics)

```bash
# Port forward Prometheus UI
kubectl port-forward -n monitoring svc/prometheus-server 9090:80

# Open browser
open http://localhost:9090
```

**Useful Queries:**
- `up` - See all scrape targets
- `container_memory_usage_bytes{namespace="portfolio"}` - Portfolio memory usage
- `rate(http_requests_total[5m])` - API request rate

---

### Grafana (Dashboards)

```bash
# Port forward Grafana UI
kubectl port-forward -n monitoring svc/grafana 3000:80

# Or use NodePort
open http://localhost:30300
```

**Login:**
- Username: `admin`
- Password: `admin` (change on first login!)

**Pre-configured Dashboards:**
- Kubernetes Cluster Monitoring
- Node Exporter Full
- Pod Resource Usage

---

### ArgoCD (GitOps)

```bash
# Port forward ArgoCD UI
kubectl port-forward -n argocd svc/argocd-server 8080:443

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
    -o jsonpath="{.data.password}" | base64 -d && echo

# Open browser (accept self-signed cert)
open https://localhost:8080
```

**Login:**
- Username: `admin`
- Password: (from command above)

**Change password:**
```bash
# After logging in, go to User Info > Update Password
# Or via CLI:
argocd account update-password
```

---

## 🧪 Testing

### Test LocalStack

```bash
# Create S3 bucket
aws --endpoint-url=http://localhost:4566 s3 mb s3://portfolio-test

# List buckets
aws --endpoint-url=http://localhost:4566 s3 ls

# Upload file
echo "Hello LocalStack!" > test.txt
aws --endpoint-url=http://localhost:4566 s3 cp test.txt s3://portfolio-test/

# Download file
aws --endpoint-url=http://localhost:4566 s3 cp s3://portfolio-test/test.txt downloaded.txt
cat downloaded.txt
```

### Test OPA Gatekeeper

```bash
# Check Gatekeeper is running
kubectl get pods -n gatekeeper-system

# View constraint templates
kubectl get constrainttemplates

# Apply Portfolio policies (from GP-copilot)
kubectl apply -f GP-copilot/gatekeeper-policies/
```

### Test Prometheus

```bash
# Port forward
kubectl port-forward -n monitoring svc/prometheus-server 9090:80 &

# Check targets
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'

# Query metrics
curl -s 'http://localhost:9090/api/v1/query?query=up' | jq '.data.result[] | {instance: .metric.instance, value: .value}'
```

### Test Grafana

```bash
# Port forward
kubectl port-forward -n monitoring svc/grafana 3000:80 &

# Check health
curl -s http://localhost:3000/api/health | jq

# Login and view dashboards
open http://localhost:3000
```

### Test ArgoCD

```bash
# Port forward
kubectl port-forward -n argocd svc/argocd-server 8080:443 &

# Install ArgoCD CLI (optional)
brew install argocd  # macOS
# OR
curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64

# Login via CLI
argocd login localhost:8080

# List applications
argocd app list
```

---

## 🗑️ Uninstall

### Uninstall All Addons

```bash
cd infrastructure/addons
./uninstall-all.sh
```

This removes:
- All addon namespaces
- All Helm releases
- All Kubernetes resources

### Uninstall Individual Addon

```bash
# ArgoCD
kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl delete namespace argocd

# Grafana
helm uninstall grafana -n monitoring

# Prometheus
helm uninstall prometheus -n monitoring
kubectl delete namespace monitoring

# LocalStack
kubectl delete -f infrastructure/addons/localstack/manifests/
kubectl delete namespace localstack

# OPA Gatekeeper
kubectl delete -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/release-3.14/deploy/gatekeeper.yaml
```

---

## 🔧 Troubleshooting

### Pods Not Starting

```bash
# Check pod status
kubectl get pods -n <namespace>

# Describe pod
kubectl describe pod <pod-name> -n <namespace>

# View logs
kubectl logs <pod-name> -n <namespace>

# Check events
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```

### Port Forward Not Working

```bash
# Kill existing port forwards
pkill -f "kubectl port-forward"

# Restart port forward
kubectl port-forward -n <namespace> svc/<service-name> <local-port>:<remote-port>
```

### Helm Installation Fails

```bash
# Update Helm repos
helm repo update

# Check Helm version (requires 3.x)
helm version

# Uninstall and reinstall
helm uninstall <release-name> -n <namespace>
helm install <release-name> <chart> -n <namespace> --values values.yaml
```

### LocalStack Not Reachable

```bash
# Check pod is running
kubectl get pods -n localstack

# Check service
kubectl get svc -n localstack

# Port forward manually
kubectl port-forward -n localstack svc/localstack 4566:4566

# Test
curl http://localhost:4566/_localstack/health
```

---

## 📚 Next Steps

After installation:

1. **Configure ArgoCD for Portfolio Method 3:**
   ```bash
   cd infrastructure/method3-helm-argocd
   # Follow README to create ArgoCD Application
   ```

2. **Use LocalStack for Terraform Method 2:**
   ```bash
   cd infrastructure/method2-terraform-localstack
   # Run terraform init && terraform plan
   ```

3. **Set up Grafana dashboards:**
   - Login to Grafana
   - Explore pre-configured dashboards
   - Create custom dashboard for Portfolio metrics

4. **Configure OPA policies:**
   ```bash
   # Apply Portfolio Gatekeeper policies
   kubectl apply -f GP-copilot/gatekeeper-policies/
   ```

---

## 🆘 Support

- **Full Documentation:** See `README.md` in this directory
- **Test Health:** Run `./test-addons.sh`
- **GitHub Issues:** https://github.com/jimjrxieb/Portfolio/issues

---

**Created:** November 14, 2025
**Maintained By:** Jimmie Coleman - Portfolio Platform
