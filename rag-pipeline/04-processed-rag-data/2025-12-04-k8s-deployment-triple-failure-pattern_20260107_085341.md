# K8s Deployment Triple Failure Pattern
Date: 2025-12-04

## Quick Reference

Three issues prevented `kubectl apply -f .` from working automatically after server restart.

## Issue 1: Port 80 Blocked by System Nginx

**Symptom:** curl returns Ubuntu nginx 404, not K8s ingress
**Cause:** Ubuntu system nginx running on port 80, blocking Docker Desktop LoadBalancer
**Fix:** `sudo systemctl disable --now nginx`

## Issue 2: CreateContainerConfigError

**Symptom:** Pod stuck in CreateContainerConfigError
**Cause:** Secret `portfolio-api-secrets` not found (secrets not in yaml files)
**Fix:** `python3 00-create-secrets.py` before kubectl apply

## Issue 3: RAG Initialization Failed

**Symptom:** API health shows `rag_status: initialization failed`
**Cause:** `CHROMA_HOST=chroma` but service is named `chromadb`
**Fix:** Update `05-api-deployment.yaml` to use `chromadb`

## Correct Deployment Order

```bash
# One-time: free port 80
sudo systemctl disable --now nginx

# Every deployment
python3 00-create-secrets.py
kubectl apply -f .
python3 99-deploy-cloudflare.py  # optional
```

## Key Diagnostic Commands

```bash
# Check port 80 owner
ss -tlnp | grep :80

# Check pod errors
kubectl describe pod -n portfolio <pod-name>

# Check service names
kubectl get svc -n portfolio

# Check API logs
kubectl logs -n portfolio -l app=portfolio-api
```