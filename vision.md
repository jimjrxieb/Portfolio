# Portfolio Application Deployment - Session Vision & Progress

## Session Date: October 2, 2025

## Primary Goal
Deploy the Portfolio application (UI + API + Jade-Brain chat) to Kubernetes and make it accessible at **https://linksmlm.com** so 600 visitors can interact with the AI assistant that answers questions about Jimmie's professional experience.

## Critical User Requirements (Clarified During Session)

### 1. **RAG is Vector Data, NOT the Pipeline**
- User has **PRE-EMBEDDED data** in `/home/jimmie/linkops-industries/Portfolio/data/chroma/chroma.sqlite3`
- This ChromaDB contains information about:
  - Guidepoint experience
  - ZRS Management work
  - CKA certification
  - Security+ certification
  - GenAI work over company documents
  - Portfolio projects
- **DO NOT run the embedding pipeline** - just query existing data
- The chat (Jade-Brain) should answer questions about the user using this existing vector data

### 2. **No Avatar Functionality**
- User explicitly stated: "delete. there is no avatar"
- Avatar router and related functionality removed

### 3. **Site Purpose**
- User stated: "the point is to have the chat answer questions about me. ill need to update some other stuff aswell"
- Chat must be functional for visitors to learn about Jimmie's experience

---

## What We Accomplished ✅

### 1. Fixed API Import Errors
**Problem:** API was crashing on startup with `ImportError: cannot import name 'settings' from 'settings'`

**Root Cause:** Multiple files were using incorrect import statement:
- Wrong: `from app.settings import settings`
- Wrong: `from settings import settings`
- Correct: `import settings`

**Files Fixed:**
- `/api/routes/health.py:7` - Changed to `import settings`
- `/api/routes/uploads.py:4` - Changed to `import settings`
- `/api/routes/actions.py:7` - Changed to `import settings`
- `/api/routes/debug.py` - Changed to `import settings`
- `/api/routes/avatar.py` - Changed to `import settings` (though avatar is disabled)
- `/api/services/did.py` - Changed to `import settings`
- `/api/services/elevenlabs.py` - Changed to `import settings`

**Result:** API now starts cleanly with no errors

### 2. Implemented Lazy Loading for RAG Engine
**Problem:** API tried to load `sentence-transformers/all-MiniLM-L6-v2` model on startup and crashed

**Solution:** Modified `/api/routes/chat.py` (lines 77-100) to defer RAG engine initialization:

```python
# Initialize engines (lazy load to avoid startup crashes)
rag_engine = None
llm_engine = None
conversation_engine = ConversationEngine()

def get_rag_engine():
    global rag_engine
    if rag_engine is None:
        try:
            rag_engine = RAGEngine()
        except Exception as e:
            print(f"Warning: RAG engine initialization failed: {e}")
            rag_engine = None
    return rag_engine

def get_llm_engine():
    global llm_engine
    if llm_engine is None:
        try:
            llm_engine = LLMEngine()
        except Exception as e:
            print(f"Warning: LLM engine initialization failed: {e}")
            llm_engine = None
    return llm_engine
```

**Result:** API no longer crashes on startup

### 3. Removed Avatar Functionality
**Problem:** Avatar router had import errors: `ModuleNotFoundError: No module named 'app'`

**User Directive:** "delete. there is no avatar"

**Solution:** Modified `/api/main.py`:
- Line 14: Commented out `# from routes.avatar import router as avatar_router`
- Line 130: Commented out `# app.include_router(avatar_router, prefix="/api", tags=["avatar"])`

**Result:** Avatar-related errors eliminated

### 4. Successfully Deployed API to Kubernetes
**Current Status:**
- Pod: `portfolio-api-55d976d5df-wwjpq` - **RUNNING** (no restarts)
- Service: `portfolio-api` - ClusterIP `10.110.224.166:8000`
- Health check: ✅ Responding at `/health`
- Logs show clean startup:
  ```
  INFO:     Started server process [1]
  INFO:     Waiting for application startup.
  INFO:     Application startup complete.
  INFO:     Uvicorn running on http://0.0.0.0:8000 (Press CTRL+C to quit)
  ```

### 5. Port-Forwarded API for Local Testing
**Command:** `kubectl port-forward -n portfolio svc/portfolio-api 8002:8000`

**Verification:**
```bash
curl http://localhost:8002/health
# Response: {"status": "healthy", "service": "portfolio-api", "version": "2.0.0"}
```

**Result:** API accessible at `localhost:8002`

### 6. Site is LIVE at https://linksmlm.com
**Components Running:**
- ✅ UI Pod: `portfolio-ui-8577cbd78c-8zdsg` - RUNNING
- ✅ API Pod: `portfolio-api-55d976d5df-wwjpq` - RUNNING
- ✅ Cloudflare Tunnel: Connected with 4 connections
- ✅ Nginx Ingress Controller: Installed and routing traffic
- ✅ Site accessible at https://linksmlm.com (user confirmed with screenshot)

**User Confirmation:** Screenshot showed "HELLO" message and chat interface

---

## Known Issues & Next Steps

### Issue 1: Browser Cannot Reach localhost:8002 API
**Problem:** UI at https://linksmlm.com (accessed from internet) tries to reach API at `http://localhost:8002`, which only works locally

**Root Cause:** API needs to be accessible through Cloudflare tunnel, not just localhost

**Potential Solutions:**
1. Configure Cloudflare tunnel to route `/api/*` requests to the API service
2. Update UI build to use production API URL
3. Set up ingress rules to route API traffic through the same domain

**Impact:** Chat shows "Failed to fetch" error because browser can't reach the API

### Issue 2: ChromaDB Not Deployed
**Status:** ChromaDB pod disabled in `values.dev.yaml` (line 40: `enabled: false`)

**Problem Encountered:** When enabled, pod stuck in `ContainerCreating` due to hostPath mount issue:
```
MountVolume.SetUp failed for volume "chroma-data" : hostPath type check failed:
/home/jimmie/linkops-industries/Portfolio/data/chroma is not a directory
```

**Context:** Docker Desktop on WSL has path mounting challenges

**Impact:** API currently can't query the pre-embedded vector data

**Solutions to Consider:**
1. Run ChromaDB as standalone service outside Kubernetes
2. Use PersistentVolume instead of hostPath
3. Copy data into a proper Kubernetes volume
4. Point API to ChromaDB URL if running externally

### Issue 3: UI Environment Configuration
**Current Config:** UI's `src/lib/api.ts` has:
```typescript
import.meta.env.VITE_API_BASE_URL || 'http://localhost:8002'
```

**Question:** Does production build need `VITE_API_BASE_URL` set to point to the correct API endpoint?

---

## Important File References

### Modified Files (This Session)
1. **[/api/routes/chat.py](api/routes/chat.py)** - Lines 77-100: Lazy loading implementation
2. **[/api/main.py](api/main.py)** - Lines 14, 130: Avatar router removed
3. **[/api/routes/health.py](api/routes/health.py)** - Line 7: Fixed import
4. **[/api/routes/uploads.py](api/routes/uploads.py)** - Line 4: Fixed import
5. **[/api/routes/actions.py](api/routes/actions.py)** - Line 7: Fixed import
6. **[/api/routes/debug.py](api/routes/debug.py)** - Fixed import
7. **[/api/routes/avatar.py](api/routes/avatar.py)** - Fixed import (disabled)
8. **[/api/services/did.py](api/services/did.py)** - Fixed import
9. **[/api/services/elevenlabs.py](api/services/elevenlabs.py)** - Fixed import

### Key Configuration Files
1. **[/charts/portfolio/values.dev.yaml](charts/portfolio/values.dev.yaml)** - Development config
2. **[/charts/portfolio/values.prod.yaml](charts/portfolio/values.prod.yaml)** - Production config (created earlier)
3. **[/api/settings.py](api/settings.py)** - Centralized configuration
4. **[/ui/src/lib/api.ts](ui/src/lib/api.ts)** - Line 2: API base URL config

### Critical Data Files
- **[/data/chroma/chroma.sqlite3](data/chroma/chroma.sqlite3)** - Pre-embedded vector data (7.1MB)
  - Contains Jade's knowledge about user's experience
  - DO NOT re-run embedding pipeline
  - Just query this existing data

---

## Current Kubernetes State

### Namespace: portfolio
**Pods:**
```
portfolio-api-55d976d5df-wwjpq      1/1     Running     0          10m
portfolio-ui-8577cbd78c-8zdsg       1/1     Running     0          31m
```

**Services:**
```
portfolio-api      ClusterIP   10.110.224.166   8000/TCP
portfolio-ui       ClusterIP   10.111.188.30    80/TCP
```

**Ingress:**
- Nginx ingress controller installed
- Cloudflare tunnel routes `linksmlm.com` → `localhost:8080` → UI service

**Port Forwards Active:**
- API: `localhost:8002` → `portfolio-api:8000`
- UI: `localhost:8080` → `portfolio-ui:80` (for Cloudflare tunnel)

---

## Commands for Quick Recovery

### Check Status
```bash
kubectl get pods -n portfolio
kubectl get svc -n portfolio
kubectl logs -n portfolio -l app=portfolio-api --tail=30
```

### Rebuild & Redeploy API
```bash
cd /home/jimmie/linkops-industries/Portfolio
docker build -t portfolio-api:local -f api/Dockerfile .
kubectl delete pod -n portfolio -l app=portfolio-api
sleep 5
kubectl get pods -n portfolio
```

### Port Forward API
```bash
kubectl port-forward -n portfolio svc/portfolio-api 8002:8000 > /dev/null 2>&1 &
```

### Test API Health
```bash
curl http://localhost:8002/health | python3 -m json.tool
```

### Access Site
- URL: https://linksmlm.com
- Cloudflare tunnel must be running (check background bash processes)

---

## Technical Learnings & Patterns

### 1. Module Import Pattern in Python
When `settings.py` exports module-level variables (not a class/object named `settings`):
- ✅ Correct: `import settings` then use `settings.LLM_PROVIDER`
- ❌ Wrong: `from settings import settings` (causes ImportError)
- ❌ Wrong: `from app.settings import settings` (no 'app' package)

### 2. Lazy Loading Pattern for Heavy Dependencies
Defer expensive initialization (embedding models, ChromaDB) to first use:
```python
engine = None

def get_engine():
    global engine
    if engine is None:
        try:
            engine = HeavyEngine()
        except Exception as e:
            print(f"Warning: initialization failed: {e}")
            engine = None
    return engine
```

### 3. Docker Desktop + WSL + Kubernetes + hostPath = Challenges
- hostPath volumes in Docker Desktop K8s have mounting issues with WSL paths
- Consider alternatives: PersistentVolumes, external services, or volume copies

### 4. Cloudflare Tunnel Configuration
- Token-based tunnels route specific hostnames to local ports
- Current setup: `linksmlm.com` → `localhost:8080`
- May need additional routes for API endpoints

---

## Action Items for Next Session

### Priority 1: Fix Chat Connectivity ⚠️
1. Determine how to make API accessible to browsers visiting https://linksmlm.com
   - Option A: Configure Cloudflare tunnel for API route (`/api/*`)
   - Option B: Update UI production build with correct API URL
   - Option C: Use ingress to proxy API requests

### Priority 2: Connect to ChromaDB Vector Data 🎯
1. Resolve ChromaDB deployment (hostPath issue or alternative approach)
2. Ensure API can connect to ChromaDB at runtime
3. Test that RAG queries work against existing embeddings
4. Verify chat can answer questions about user's experience

### Priority 3: Verify End-to-End Functionality ✨
1. Test chat on https://linksmlm.com from external browser
2. Verify Jade can query vector data and respond accurately
3. Confirm all user stories work (ask about Guidepoint, ZRS, certifications, etc.)
4. Monitor API logs for any runtime errors

### Priority 4: User-Mentioned Updates 📝
User said: "ill need to update some other stuff aswell"
- Clarify what additional updates are needed
- Update content/knowledge if required
- Ensure all visitor-facing features work correctly

---

## Background Processes to Monitor

Several background bash processes are running - check their status:
- Cloudflare tunnel (multiple instances may be running)
- Docker builds (may still be running)
- Port forwards

**Check with:** `jobs` or review background bash output

---

## Session End State

**Working Components:**
- ✅ API running cleanly in Kubernetes (no crashes)
- ✅ UI deployed and accessible at https://linksmlm.com
- ✅ Cloudflare tunnel connected
- ✅ Import errors fixed
- ✅ Lazy loading implemented
- ✅ Avatar functionality removed per user request

**Blocked/Pending:**
- ⏳ Chat can't reach API (localhost:8002 not accessible from browser)
- ⏳ ChromaDB not connected (deployment disabled due to hostPath issues)
- ⏳ End-to-end chat functionality not verified

**Critical Path Forward:**
1. Fix API accessibility for browser clients
2. Connect to existing ChromaDB vector data
3. Test and verify chat works for visitors

---

## Key Takeaway

**The application is 80% deployed but the critical chat functionality is blocked by networking configuration.** The API works perfectly when accessed locally (localhost:8002), but browsers accessing the site from the internet can't reach it. Solving this routing issue is the highest priority for the next session.

The pre-embedded ChromaDB data exists and is ready to use - we just need to connect the API to it and make the API accessible to the UI.
