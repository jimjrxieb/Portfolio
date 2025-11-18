# Prerequisites Before Running kubectl apply

Before running `kubectl apply -f .`, complete these steps:

## Step 1: Install Gatekeeper (Optional but Recommended)

```bash
# Add Gatekeeper Helm repo
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
helm repo update

# Install Gatekeeper
helm install gatekeeper gatekeeper/gatekeeper \
    --namespace gatekeeper-system \
    --create-namespace \
    --set replicas=3 \
    --set audit.replicas=1 \
    --set validatingWebhookConfiguration.failurePolicy=Ignore \
    --wait

# Verify
kubectl get pods -n gatekeeper-system
```

**Or use the script:**
```bash
python3 00-install-gatekeeper.py
```

## Step 2: Deploy OPA Policies (Optional but Recommended)

```bash
cd ../../GP-copilot/gatekeeper-temps/

# First pass - create ConstraintTemplates
kubectl apply -f .

# Wait for CRDs
sleep 5

# Second pass - create Constraints
kubectl apply -f .

cd -
```

**Or use the script:**
```bash
python3 00-deploy-opa-policies.py
```

## Step 3: Create Namespace

```bash
kubectl apply -f 01-namespace.yaml
```

## Step 4: Create Secrets

**Option A: From .env file (recommended)**
```bash
python3 00-create-secrets.py
```

**Option B: Manual kubectl**
```bash
kubectl create secret generic portfolio-api-secrets \
  --from-literal=CLAUDE_API_KEY="sk-ant-your-key-here" \
  -n portfolio
```

**Option C: YAML file**
```bash
# Create portfolio-secrets.yaml
cat > portfolio-secrets.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: portfolio-api-secrets
  namespace: portfolio
type: Opaque
stringData:
  CLAUDE_API_KEY: "sk-ant-your-actual-key-here"
EOF

kubectl apply -f portfolio-secrets.yaml
```

## Step 5: Now you can deploy everything!

```bash
kubectl apply -f /home/jimmie/linkops-industries/Portfolio/infrastructure/method1-simple-kubectl
```

This will apply all YAML files in the directory (01-07).

## Step 6: Install Cloudflare Tunnel (Optional)

```bash
python3 99-deploy-cloudflare.py
```

**Or manually:**
```bash
# Add Cloudflare GPG key
sudo mkdir -p --mode=0755 /usr/share/keyrings
curl -fsSL https://pkg.cloudflare.com/cloudflare-public-v2.gpg | sudo tee /usr/share/keyrings/cloudflare-public-v2.gpg >/dev/null

# Add apt repository
echo 'deb [signed-by=/usr/share/keyrings/cloudflare-public-v2.gpg] https://pkg.cloudflare.com/cloudflared any main' | sudo tee /etc/apt/sources.list.d/cloudflared.list

# Install
sudo apt-get update && sudo apt-get install -y cloudflared

# Install as service (replace with your token)
sudo cloudflared service install YOUR_TUNNEL_TOKEN_HERE
```

---

## Quick Checklist

- [ ] Gatekeeper installed (helm or script)
- [ ] OPA policies deployed (kubectl or script)
- [ ] Namespace created (`kubectl apply -f 01-namespace.yaml`)
- [ ] Secrets created (kubectl or script)
- [ ] Run `kubectl apply -f .` from method1-simple-kubectl directory
- [ ] (Optional) Cloudflare installed (script or manual)

---

## Minimal Deployment (No Gatekeeper, No Cloudflare)

If you just want the app running without security policies:

```bash
# 1. Create namespace
kubectl apply -f 01-namespace.yaml

# 2. Create secrets
kubectl create secret generic portfolio-api-secrets \
  --from-literal=CLAUDE_API_KEY="your-key" \
  -n portfolio

# 3. Deploy everything
kubectl apply -f /home/jimmie/linkops-industries/Portfolio/infrastructure/method1-simple-kubectl

# Done!
```

## Verify Deployment

```bash
# Check pods
kubectl get pods -n portfolio

# Check services
kubectl get svc -n portfolio

# Check ingress
kubectl get ingress -n portfolio

# Watch pods start
kubectl get pods -n portfolio -w
```

## Access Application

- **Local:** http://portfolio.localtest.me/
- **API:** http://portfolio.localtest.me/api/health