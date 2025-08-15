from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from settings import settings
from routes_chat import router as chat_router
from routes_uploads import router as uploads_router
from routes_avatar import router as avatar_router
from routes_health import router as health_router
from mcp_adapter import router as mcp_router

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
app.include_router(mcp_router)  # MCP action routes


