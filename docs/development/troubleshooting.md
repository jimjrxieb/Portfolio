# Troubleshooting Guide

## Quick Diagnostic Commands

### 1. Check All Services
```bash
kubectl -n portfolio get all
kubectl -n portfolio get pods -o wide
kubectl -n portfolio describe pods -l app=portfolio-api
```

### 2. Health Check Endpoints
```bash
# Port-forward first
kubectl -n portfolio port-forward svc/portfolio-api 8001:80 &

# Test health endpoints
curl http://localhost:8001/health
curl http://localhost:8001/api/health/llm  
curl http://localhost:8001/api/health/rag
```

### 3. Test Chat Pipeline
```bash
curl -H "Content-Type: application/json" \
  -d '{"message": "What is Jade?"}' \
  http://localhost:8001/api/chat
```

## Common Issues & Solutions

### "Chat Failed" in UI

**Symptoms**: UI shows "Sorry, chat failed"  
**Diagnosis**: Check `/api/health/llm` and `/api/health/rag`

#### LLM Issues (`/api/health/llm` returns `ok: false`)
```bash
# Check LLM environment variables
kubectl -n portfolio get deploy portfolio-api -o yaml | grep -A5 -B5 LLM

# Common fixes:
- LLM_API_BASE wrong (should be http://ollama-host:11434)
- LLM_MODEL_ID mismatch ("phi3" vs "phi3:latest")  
- LLM server not running
- Network connectivity issues
```

#### RAG Issues (`/api/health/rag` returns `ok: false` or `hits: 0`)
```bash
# Check if knowledge was ingested
kubectl -n portfolio exec deploy/portfolio-api -- \
  python -c "import chromadb; print(chromadb.PersistentClient('/data/chroma').get_collection('jimmie').count())"

# If count is 0, run ingestion:
kubectl -n portfolio exec deploy/portfolio-api -- \
  python -m api.scripts.ingest
```

### Avatar Upload/Talk Fails

**Check D-ID/ElevenLabs Configuration**:
```bash
# Verify secrets exist
kubectl -n portfolio get secret portfolio-secrets -o yaml

# Check environment variables
kubectl -n portfolio get deploy portfolio-api -o yaml | grep -A3 -B3 ELEVENLABS
kubectl -n portfolio get deploy portfolio-api -o yaml | grep -A3 -B3 DID
```

**Test Upload Endpoint**:
```bash
curl -F "file=@test-image.jpg" http://localhost:8001/api/upload/image
```

### Pod CrashLoopBackOff

**Check Logs**:
```bash
kubectl -n portfolio logs -l app=portfolio-api --tail=50
kubectl -n portfolio logs -l app=portfolio-ui --tail=50
```

**Common Causes**:
- Missing environment variables (LLM_API_BASE, PUBLIC_BASE_URL)
- ChromaDB permission issues in /data/chroma
- Python import errors (missing requirements)
- Port conflicts

### UI Not Loading/Stale Content

**Browser Cache**:
- Hard refresh: Ctrl+Shift+R (Chrome/Firefox)
- Clear cache for linksmlm.com

**Cloudflare Cache**:
- Dashboard → Caching → Purge Cache → Purge Everything

**Check Image Tag**:
```bash
kubectl -n portfolio get deploy portfolio-ui -o jsonpath='{.spec.template.spec.containers[0].image}'

# Should show unique tag, not just "latest"
# If "latest", rebuild with unique tag and redeploy
```

### Database/PVC Issues

**Check Storage**:
```bash
kubectl -n portfolio get pvc
kubectl -n portfolio describe pvc chroma-pvc

# Check mount in pod
kubectl -n portfolio exec deploy/portfolio-api -- ls -la /data/
kubectl -n portfolio exec deploy/portfolio-api -- df -h /data/
```

### Network/Ingress Issues

**Test Internal Connectivity**:
```bash
# From API pod, test UI
kubectl -n portfolio exec deploy/portfolio-api -- curl -I http://portfolio-ui.portfolio.svc.cluster.local

# From UI pod, test API  
kubectl -n portfolio exec deploy/portfolio-ui -- curl -I http://portfolio-api.portfolio.svc.cluster.local
```

**Check Cloudflare Tunnel**:
```bash
kubectl -n portfolio logs -l app=cloudflared --tail=20
kubectl -n portfolio get configmap cloudflared-config -o yaml
```

## Performance Debugging

### Resource Usage
```bash
kubectl top pods -n portfolio
kubectl -n portfolio describe pods -l app=portfolio-api | grep -A5 "Requests\|Limits"
```

### ChromaDB Performance
```bash
# Check collection size and query performance
kubectl -n portfolio exec deploy/portfolio-api -- \
  python -c "
import chromadb, time
c = chromadb.PersistentClient('/data/chroma')
coll = c.get_collection('jimmie')
start = time.time()
result = coll.query(['test'], n_results=1)
print(f'Count: {coll.count()}, Query time: {time.time()-start:.3f}s')
"
```

### LLM Response Time
```bash
time curl -s -H "Content-Type: application/json" \
  -d '{"message": "Hello"}' \
  http://localhost:8001/api/chat | jq .
```

## Log Analysis

### Key Log Patterns
```bash
# API startup issues
kubectl -n portfolio logs deploy/portfolio-api | grep -i error

# Chat pipeline errors  
kubectl -n portfolio logs deploy/portfolio-api | grep "Chat pipeline error"

# RAG retrieval issues
kubectl -n portfolio logs deploy/portfolio-api | grep -i chroma

# LLM connection errors
kubectl -n portfolio logs deploy/portfolio-api | grep -i "llm\|completion"
```

### Enable Debug Logging
Add to API deployment:
```yaml
env:
  - name: LOG_LEVEL
    value: "DEBUG"
```

## Emergency Recovery

### Reset ChromaDB
```bash
kubectl -n portfolio exec deploy/portfolio-api -- rm -rf /data/chroma/*
kubectl -n portfolio exec deploy/portfolio-api -- python -m api.scripts.ingest
```

### Restart All Services
```bash
kubectl -n portfolio rollout restart deploy/portfolio-api
kubectl -n portfolio rollout restart deploy/portfolio-ui
kubectl -n portfolio rollout status deploy/portfolio-api
kubectl -n portfolio rollout status deploy/portfolio-ui
```

### Clean Up Replica Sets
```bash
# Remove old replica sets (keep latest 2)
kubectl -n portfolio delete rs $(kubectl -n portfolio get rs --sort-by=.metadata.creationTimestamp -o name | head -n -2)
```