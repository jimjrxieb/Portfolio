# data-dev:routes-actions
# Action endpoints Jade can call; tagged "mcp" so they become MCP tools.
# Validate inputs, never log PII/secrets, and keep least privilege.
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, EmailStr, Field, constr
from typing import Literal

router = APIRouter(prefix="/api/actions", tags=["mcp"])

# --- Schemas ---
class SendEmailReq(BaseModel):
    to: EmailStr
    subject: constr(min_length=1, max_length=200)
    body_markdown: constr(min_length=1, max_length=5000)

class ReportReq(BaseModel):
    kind: Literal["delinquencies","workorders","rent-roll","compliance"]
    period: constr(min_length=1, max_length=40)  # e.g., "2025-08" or "last-30d"

class OnboardReq(BaseModel):
    entity: Literal["tenant","vendor"]
    name: constr(min_length=1, max_length=200)
    email: EmailStr | None = None

class WorkOrderReq(BaseModel):
    tenant_id: constr(min_length=1, max_length=64)
    description: constr(min_length=5, max_length=2000)
    priority: Literal["low","normal","high"] = "normal"

# --- Implementations (replace with your providers/RPA/MCP backends) ---
@router.post("/send-email")
def send_email(req: SendEmailReq):
    # TODO: call your SMTP/SendGrid/Gmail MCP server
    # SECURITY: redact/avoid logging body contents
    ok = True
    if not ok:
        raise HTTPException(502, "Email provider failed")
    return {"status": "sent"}

@router.post("/generate-report")
def generate_report(req: ReportReq):
    # TODO: run your LangGraph/report code and store PDF under /data/uploads/reports
    url = "/uploads/reports/demo.pdf"
    return {"status": "ok", "url": url}

@router.post("/onboard")
def onboard(req: OnboardReq):
    # TODO: call your RPA flow (MCP server for RPA) to create tenant/vendor records
    return {"status": "created", "entity": req.entity}

@router.post("/work-order")
def work_order(req: WorkOrderReq):
    # TODO: create WO in your system and email stakeholders
    return {"status": "created", "ticket": "WO-12345"}