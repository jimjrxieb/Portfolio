from pydantic import BaseModel

class HealthResponse(BaseModel):
    ok: bool
    service: str | None = None
    status: str | None = None
    details: dict | None = None

class ErrorResponse(BaseModel):
    error: str
    details: str | None = None