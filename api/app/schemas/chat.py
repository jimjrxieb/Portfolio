from pydantic import BaseModel, constr

class ChatRequest(BaseModel):
    message: constr(strip_whitespace=True, min_length=1, max_length=4000)
    context: str | None = None

class ChatResponse(BaseModel):
    response: str
    context: str | None = None