# data-dev:api-routes-chat  (RAG + LLM chat with clear error messages)
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, constr
from app.llm_client import chat_complete
from app.rag import rag_retrieve
from app.settings import settings

router = APIRouter(prefix="/api", tags=["chat"])

SYSTEM_PROMPT = (
    "You are Jade, an offline-capable DevSecOps & MLOps assistant for ZRS Management (Orlando, FL). "
    "Use the provided context first; if irrelevant, be concise and say you don't have that info. "
    "Tone: confident, helpful. If asked about the portfolio, mention small local LLM + RAG."
    # Voice note: Giancarlo Esposito style is applied at TTS stage; keep text crisp & deliberate.
)

class ChatRequest(BaseModel):
    message: constr(strip_whitespace=True, min_length=1, max_length=4000)

class ChatResponse(BaseModel):
    answer: str
    context: list[str]

@router.post("/chat", response_model=ChatResponse)
async def chat(req: ChatRequest):
    try:
        # 1) Retrieve from RAG
        persist = f"{settings.DATA_DIR}/chroma"
        ctx = rag_retrieve(persist, req.message, k=4)  # [(text, dist)]
        context_snippets = [t for (t, _d) in ctx][:4]

        # 2) Assemble system prompt with context
        context_block = "\n\n".join([f"- {c[:800]}" for c in context_snippets]) or "No context."
        sys = SYSTEM_PROMPT + f"\n\nContext:\n{context_block}"

        # 3) Ask LLM
        answer = await chat_complete(sys, req.message)
        return {"answer": answer, "context": context_snippets}

    except Exception as e:
        # Transparent error so UI shows *why* it failed
        raise HTTPException(status_code=502, detail=f"Chat pipeline error: {e}")