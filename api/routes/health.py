# data-dev:api-routes-health  (health endpoints for UI tests/alerts)
from fastapi import APIRouter
from app.settings import settings
import httpx
from app.rag import rag_retrieve

router = APIRouter(prefix="/api", tags=["health"])

@router.get("/health")
def health_root():
    return {"ok": True}

@router.get("/health/llm")
async def health_llm():
    try:
        payload = {"model": settings.LLM_MODEL, "messages":[{"role":"user","content":"ping"}], "max_tokens": 5}
        headers = {"Content-Type":"application/json"}
        if settings.LLM_API_KEY:
            headers["Authorization"] = f"Bearer {settings.LLM_API_KEY}"
        async with httpx.AsyncClient(base_url=str(settings.LLM_API_BASE), timeout=15.0) as client:
            r = await client.post("/v1/chat/completions", headers=headers, json=payload)
            ok = r.status_code == 200
            return {"ok": ok, "status_code": r.status_code, "provider": settings.LLM_PROVIDER, "model": settings.LLM_MODEL}
    except Exception as e:
        return {"ok": False, "error": str(e), "provider": settings.LLM_PROVIDER, "model": settings.LLM_MODEL}

@router.get("/health/rag")
def health_rag():
    try:
        results = rag_retrieve(f"{settings.DATA_DIR}/chroma", "What is Jade?", k=1)
        return {
            "ok": True, 
            "hits": len(results),
            "namespace": settings.RAG_NAMESPACE,
            "chroma_url": str(settings.CHROMA_URL)
        }
    except Exception as e:
        return {
            "ok": False, 
            "error": str(e),
            "namespace": settings.RAG_NAMESPACE,
            "chroma_url": str(settings.CHROMA_URL)
        }