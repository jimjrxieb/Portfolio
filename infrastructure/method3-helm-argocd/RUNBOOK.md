# Method 3 Runbook: Production Deployment (Helm + ArgoCD)

Bare server to production deployment at linksmlm.com. This is the runbook for the live system.

---

## 1. Clone the Repository

```bash
ssh jimmie@your-server
git clone https://github.com/jimjrxieb/Portfolio.git
cd Portfolio
```

---

## 2. Prerequisites

| Requirement | Details |
|-------------|---------|
| Ubuntu server | Physical or VM with SSH access |
| Domain | Configured in Cloudflare (e.g., linksmlm.com) |
| GitHub access | Push access to the repo, GHCR token for image registry |
| API keys | CLAUDE_API_KEY, OPENAI_API_KEY (optional), ELEVENLABS_API_KEY, DID_API_KEY |

---

## 3. Install k3s

```bash
curl -sfL https://get.k3s.io | sh -

# Configure kubectl
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
export KUBECONFIG=~/.kube/config
echo 'export KUBECONFIG=~/.kube/config' >> ~/.bashrc

# Verify
kubectl get nodes   # should show Ready
```

---

## 4. Sysctl Tuning

Required for cloudflared UDP buffer sizes:

```bash
sudo tee -a /etc/sysctl.conf << 'EOF'
net.core.rmem_max=7500000
net.core.wmem_max=7500000
EOF

sudo sysctl -p
```

---

## 5. Install Helm

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version
```

---

## 6. Apply Cluster Hardening

Run the consulting package for CIS benchmark compliance:

```bash
cd /home/jimmie/linkops-industries/GP-copilot/GP-CONSULTING/02-CLUSTER-HARDENING/

# Run cluster audit (CIS Kubernetes Benchmark)
bash tools/run-cluster-audit.sh

# Review ENGAGEMENT-GUIDE.md for the audit → enforce workflow
# Deploy policies in audit mode first, then enforce after validation
cd ~/Portfolio
```

---

## 7. Install cert-manager

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.yaml

# Wait for cert-manager pods
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=120s

# Create Let's Encrypt ClusterIssuer
kubectl apply -f - << 'EOF'
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
      - http01:
          ingress:
            class: traefik
EOF
```

---

## 8. Install Gatekeeper

```bash
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
helm repo update

helm install gatekeeper gatekeeper/gatekeeper \
  --namespace gatekeeper-system \
  --create-namespace

kubectl wait --for=condition=ready pod -l control-plane=controller-manager -n gatekeeper-system --timeout=120s
```

---

## 9. Install ArgoCD

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD server
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=180s

# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo
```

Save the admin password. Access ArgoCD at `https://argocd.linksmlm.com` (after tunnel setup) or via port-forward: `kubectl port-forward svc/argocd-server -n argocd 8080:443`.

---

## 10. Install Prometheus + Grafana

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace
```

---

## 11. Create Portfolio Namespace and Secrets

```bash
kubectl create namespace portfolio

kubectl create secret generic portfolio-api-secrets \
  --from-literal=CLAUDE_API_KEY="sk-ant-..." \   # pragma: allowlist secret
  --from-literal=OPENAI_API_KEY="sk-..." \      # pragma: allowlist secret
  --from-literal=ELEVENLABS_API_KEY="..." \
  --from-literal=DID_API_KEY="..." \
  -n portfolio
```

---

## 12. Deploy ArgoCD Application

```bash
kubectl apply -f infrastructure/method3-helm-argocd/argocd/portfolio-application.yaml
```

ArgoCD will:
1. Clone the repo
2. Render the Helm chart at `infrastructure/charts/portfolio/`
3. Deploy all resources to the `portfolio` namespace
4. Auto-sync on any future changes (self-heal + prune enabled)

Watch the sync:

```bash
kubectl get application -n argocd portfolio -w
```

Wait for `Synced` and `Healthy` status.

---

## 13. Set Up Cloudflare Tunnel

### Install cloudflared

```bash
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb -o cloudflared.deb
sudo dpkg -i cloudflared.deb
```

### Configure in Cloudflare Zero Trust Dashboard

1. Go to **Zero Trust > Networks > Tunnels**
2. Create a tunnel (or use existing), copy the tunnel token
3. Add a public hostname:
   - **Hostname:** `linksmlm.com`
   - **Service:** `http://192.168.1.110:80` (your server's LAN IP + Traefik port)
   - **HTTP Host Header:** `linksmlm.com` (required — without this, Traefik returns 404)
4. Optionally add `argocd.linksmlm.com` → ArgoCD service (with noTLSVerify)

### Enable as systemd service

```bash
sudo cloudflared service install <TUNNEL_TOKEN>

# Override to force http2 protocol (QUIC is blocked on many networks)
sudo mkdir -p /etc/systemd/system/cloudflared.service.d
sudo tee /etc/systemd/system/cloudflared.service.d/override.conf << 'EOF'
[Service]
ExecStart=
ExecStart=/usr/bin/cloudflared --protocol http2 tunnel run --token <TUNNEL_TOKEN>
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now cloudflared
sudo systemctl status cloudflared
```

### DNS (Cloudflare Dashboard)

Create a CNAME record:
- **Name:** `linksmlm.com` (or `@`)
- **Target:** Tunnel UUID `.cfargotunnel.com`
- **Proxied:** Yes

---

## 14. Set Up CI/CD

### GitHub Secrets

In the repo settings (Settings > Secrets and variables > Actions), add:

| Secret | Value |
|--------|-------|
| `GHCR_TOKEN` | GitHub personal access token with `write:packages` scope |

### How Auto-Deploy Works

1. Push to `main` branch
2. GitHub Actions builds Docker images tagged `main-<short-sha>`
3. Pushes images to `ghcr.io/jimjrxieb/`
4. Updates image tags in `infrastructure/charts/portfolio/values.yaml` (auto-commit `[skip ci]`)
5. ArgoCD polls repo every 3 minutes, detects changed values.yaml
6. ArgoCD renders Helm chart, applies diff → rolling update with zero downtime

---

## 15. Verify

```bash
# App health
curl https://linksmlm.com/api/health

# ArgoCD status
kubectl get application -n argocd portfolio
# Should show: Synced, Healthy

# All pods running
kubectl get pods -n portfolio
# Should show: api, ui, chroma pods all Running

# Tunnel status
sudo systemctl status cloudflared
journalctl -u cloudflared --no-pager -n 20
```

---

## 16. Troubleshooting

**502 from linksmlm.com:**
Check cloudflared — `sudo systemctl status cloudflared`. Verify `httpHostHeader: linksmlm.com` is set in the Zero Trust dashboard. Restart: `sudo systemctl restart cloudflared`.

**White page after deploy:**
New UI image built but browser cached old asset hashes. Force refresh (Ctrl+Shift+R). If persistent, check nginx logs: `kubectl -n portfolio logs <ui-pod>`.

**Tunnel not proxying:**
Confirm protocol is http2: `journalctl -u cloudflared | grep protocol`. QUIC does not work on this network. Check sysctl tuning (step 4).

**Pods healthy but site down:**
Tunnel issue, not K8s. Test locally: `curl -H 'Host: linksmlm.com' http://192.168.1.110:80`.

**Chat not working:**
Verify fetch URLs use `/api/chat` prefix. Test: `curl https://linksmlm.com/api/chat/health`.

**ArgoCD stuck OutOfSync:**
Force sync: `argocd app sync portfolio`. Check for admission webhook blocking: `kubectl get events -n portfolio --sort-by=.lastTimestamp`.

---

## 17. Teardown

```bash
# Remove the ArgoCD application (this deletes all portfolio resources)
kubectl delete application portfolio -n argocd

# Or delete the namespace directly
kubectl delete namespace portfolio
```

To fully decommission the server, also remove ArgoCD, cert-manager, Gatekeeper, monitoring, and cloudflared.
