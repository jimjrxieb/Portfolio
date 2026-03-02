# Method 1 Runbook: Simple kubectl Deployment

Git clone to fully deployed portfolio on a local Kubernetes cluster.

---

## 1. Clone the Repository

```bash
git clone https://github.com/jimjrxieb/Portfolio.git
cd Portfolio
```

---

## 2. Prerequisites

Install before proceeding:

| Tool | Install |
|------|---------|
| Docker Desktop | https://docs.docker.com/desktop/ — enable Kubernetes in settings |
| kubectl | Bundled with Docker Desktop, or `brew install kubectl` |
| Python 3.6+ | `python3 --version` to verify |
| Ollama | https://ollama.com/download |

If using kind or minikube instead of Docker Desktop K8s, start your cluster now.

### WSL2/Ubuntu: Free Port 80

Docker Desktop's LoadBalancer needs port 80. If system nginx is running:

```bash
sudo systemctl disable --now nginx
ss -tlnp | grep :80   # should be empty
```

---

## 3. Start Ollama

```bash
# Terminal 1: start the server
ollama serve

# Terminal 2: pull the embedding model
ollama pull nomic-embed-text

# Verify
curl http://localhost:11434/api/tags
```

---

## 4. Install NGINX Ingress Controller

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml

# Wait for controller pod to be ready
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s
```

---

## 5. Create Namespace

```bash
cd infrastructure/method1-simple-kubectl
kubectl apply -f 01-namespace.yaml
```

---

## 6. Create Secrets

Create a `.env` file in the **project root** with your API keys:

```bash
cat > ../../.env << 'EOF'
CLAUDE_API_KEY=sk-ant-...
OPENAI_API_KEY=sk-...
ELEVENLABS_API_KEY=...
DID_API_KEY=...
EOF
```

Then create the Kubernetes secret:

```bash
python3 00-create-secrets.py
```

Alternatively, create secrets directly:

```bash
kubectl create secret generic portfolio-api-secrets \
  --from-literal=CLAUDE_API_KEY="your-claude-key" \       # pragma: allowlist secret
  --from-literal=OPENAI_API_KEY="your-openai-key" \      # pragma: allowlist secret
  --from-literal=ELEVENLABS_API_KEY="your-elevenlabs-key" \  # pragma: allowlist secret
  --from-literal=DID_API_KEY="your-did-key" \             # pragma: allowlist secret
  -n portfolio
```

---

## 7. Create RAG Data ConfigMap

```bash
kubectl create configmap rag-data \
  --from-file=../../rag-pipeline/04-processed-rag-data/ \
  -n portfolio
```

The API deployment's init containers will sync this data to ChromaDB automatically on every pod start.

---

## 8. Deploy Manifests (in order)

```bash
kubectl apply -f 03-chroma-pv-local.yaml
kubectl apply -f 03b-chroma-log-config.yaml
kubectl apply -f 04-chroma-deployment.yaml
kubectl apply -f 05-api-deployment.yaml
kubectl apply -f 06-ui-deployment.yaml
kubectl apply -f 07-ingress.yaml
```

Or apply everything at once (file numbering preserves order):

```bash
kubectl apply -f .
```

---

## 9. Verify

```bash
# All pods should be Running (wait for init containers to complete)
kubectl get pods -n portfolio -w

# Services should exist
kubectl get svc -n portfolio

# Ingress should have an address
kubectl get ingress -n portfolio

# Health check
curl http://portfolio.localtest.me/api/health
```

Expected output:

| Resource | Expected State |
|----------|---------------|
| chroma pod | Running |
| portfolio-api pod | Running (after init containers complete) |
| portfolio-ui pod | Running |
| ingress | ADDRESS = localhost or 127.0.0.1 |

Access the app:
- **UI:** http://portfolio.localtest.me
- **API:** http://portfolio.localtest.me/api/health

---

## 10. Teardown

```bash
kubectl delete namespace portfolio
```

---

## Troubleshooting

**Pods stuck in Init:** Check init container logs — `kubectl logs -n portfolio <pod> -c wait-for-chromadb`

**Ingress 404:** Verify NGINX ingress controller is running — `kubectl get pods -n ingress-nginx`

**Ollama connection refused:** Ensure Ollama is running and accessible from containers. Check API logs — `kubectl logs -n portfolio deployment/portfolio-api | grep ollama`

**Port 80 in use:** On WSL2, disable system nginx (see step 2).
