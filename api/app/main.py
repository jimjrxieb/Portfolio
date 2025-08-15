from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from app.settings import settings
from app.routes.chat import router as chat_router
from app.routes.uploads import router as uploads_router
from app.routes.avatar import router as avatar_router
from app.routes.health import router as health_router
from app.routes.actions import router as actions_router
from app.mcp.adapter import router as mcp_router

app = FastAPI(title="Portfolio API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://linksmlm.com", "https://www.linksmlm.com", "http://localhost:5173"],
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/health")
def health():
    return {"ok": True}

# Serve /uploads/** from /data/uploads/**
app.mount("/uploads", StaticFiles(directory=f"{settings.DATA_DIR}/uploads"), name="uploads")

app.include_router(chat_router)
app.include_router(uploads_router)
app.include_router(avatar_router)
app.include_router(health_router)
app.include_router(actions_router)
app.include_router(mcp_router)  # MCP action routes