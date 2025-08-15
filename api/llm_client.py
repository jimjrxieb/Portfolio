import httpx
from settings import settings

async def chat_complete(system_prompt: str, user_message: str) -> str:
    """
    Calls an OpenAI-compatible /v1/chat/completions endpoint.
    Compatible with vLLM, LM Studio, Ollama (with openai proxy), etc.
    """
    payload = {
        "model": settings.LLM_MODEL_ID,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_message},
        ],
        "temperature": 0.2,
    }
    headers = {"Content-Type": "application/json"}
    if settings.LLM_API_KEY:
        headers["Authorization"] = f"Bearer {settings.LLM_API_KEY}"

    timeout = httpx.Timeout(60.0, connect=10.0)
    async with httpx.AsyncClient(base_url=str(settings.LLM_API_BASE), timeout=timeout) as client:
        r = await client.post("/v1/chat/completions", headers=headers, json=payload)
        r.raise_for_status()
        data = r.json()
        return data["choices"][0]["message"]["content"]