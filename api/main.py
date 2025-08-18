"""
Portfolio API - Main FastAPI Application
Clean, documented entry point for all backend services
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
import os
from pathlib import Path

# Import route modules
from routes.chat import router as chat_router
from routes.avatar import router as avatar_router
from routes.health import router as health_router
from routes.uploads import router as uploads_router

# Create FastAPI app
app = FastAPI(
    title="Portfolio API",
    description="Backend API for Jimmie's AI-powered portfolio platform",
    version="2.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# Configure CORS
CORS_ORIGINS = os.getenv("CORS_ORIGINS", "http://localhost:5173,https://linksmlm.com").split(",")
app.add_middleware(
    CORSMiddleware,
    allow_origins=[origin.strip() for origin in CORS_ORIGINS],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["Content-Type", "Authorization"],
)

# Configure static file serving
DATA_DIR = os.getenv("DATA_DIR", "/data")
app.mount("/uploads", StaticFiles(directory=f"{DATA_DIR}/uploads"), name="uploads")
app.mount("/assets", StaticFiles(directory=f"{DATA_DIR}/assets"), name="assets")

# Health check endpoint
@app.get("/health")
def health_check():
    """Basic health check endpoint"""
    return {
        "status": "healthy",
        "service": "portfolio-api",
        "version": "2.0.0"
    }

# Include routers
app.include_router(health_router, prefix="/api", tags=["health"])
app.include_router(chat_router, prefix="/api", tags=["chat"])
app.include_router(avatar_router, prefix="/api", tags=["avatar"])
app.include_router(uploads_router, prefix="/api", tags=["uploads"])

# Root endpoint
@app.get("/")
def root():
    """API root endpoint"""
    return {
        "message": "Portfolio API v2.0.0",
        "docs": "/docs",
        "health": "/health"
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)