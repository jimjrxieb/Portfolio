# K8s Docker Image Deployment Pattern
Date: 2025-12-04

## Problem
Local code changes weren't being reflected in K8s deployment. The deployed container had old code with a different method signature, causing silent failures in RAG retrieval.

## Key Discovery
- Local code: `generate_response(self, question=None, context=None, rag_results=None)`
- Container code: `generate_response(self, context)` (OLD!)
- Docker Desktop K8s caches images aggressively
- OPA Gatekeeper blocks images from untrusted registries

## Solution: Full Rebuild and Push Cycle
```bash
# 1. Rebuild image
docker build -f api/Dockerfile -t portfolio-api:latest .

# 2. Tag for allowed registry
docker tag portfolio-api:latest ghcr.io/jimjrxieb/portfolio-api:backend-v2

# 3. Push to registry
docker push ghcr.io/jimjrxieb/portfolio-api:backend-v2

# 4. Update K8s deployment
kubectl set image deployment/portfolio-api -n portfolio \
  api=ghcr.io/jimjrxieb/portfolio-api:backend-v2
```

## Verification Commands
```bash
# Check deployed image
kubectl get deployment portfolio-api -n portfolio \
  -o jsonpath='{.spec.template.spec.containers[0].image}'

# Check actual code in container
kubectl exec -n portfolio deployment/portfolio-api -- \
  grep -A5 "def generate_response" /app/routes/chat.py
```

## Trade-offs
- **Accepted**: Must push to ghcr.io (OPA policy requirement)
- **Accepted**: Use versioned tags, not `:latest`
- **Avoided**: Disabling security policies for convenience

## When to Use
- Code changes not appearing in deployed app
- Method signature or import errors in logs
- Silent failures where API returns 200 but wrong behavior

## Key Insight
Never assume local code matches deployed code. K8s image caching + OPA policies mean you must: rebuild, tag with version, push to allowed registry, then update deployment.
