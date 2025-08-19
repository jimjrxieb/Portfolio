"""
Portfolio API - Main FastAPI Application
Clean, documented entry point for all backend services
"""

from fastapi import FastAPI, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.gzip import GZipMiddleware
import os
import time
from pathlib import Path
from collections import defaultdict
from datetime import datetime, timedelta

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
    redoc_url="/redoc",
)

# Simple rate limiting (in-memory)
rate_limit_store = defaultdict(list)


def rate_limit_check(
    client_ip: str, max_requests: int = 30, window_minutes: int = 1
) -> bool:
    """Simple in-memory rate limiting"""
    now = datetime.now()
    window_start = now - timedelta(minutes=window_minutes)

    # Clean old requests
    rate_limit_store[client_ip] = [
        req_time for req_time in rate_limit_store[client_ip] if req_time > window_start
    ]

    # Check if under limit
    if len(rate_limit_store[client_ip]) >= max_requests:
        return False

    # Add current request
    rate_limit_store[client_ip].append(now)
    return True


# Security middleware
@app.middleware("http")
async def security_headers(request: Request, call_next):
    """Add security headers to all responses"""
    response = await call_next(request)

    # Security headers
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    response.headers["Content-Security-Policy"] = (
        "default-src 'self'; "
        "script-src 'self' 'unsafe-inline'; "
        "style-src 'self' 'unsafe-inline'; "
        "img-src 'self' data: https:; "
        "connect-src 'self' https://api.openai.com; "
        "frame-ancestors 'none';"
    )

    # HSTS (only in production)
    if request.url.scheme == "https":
        response.headers["Strict-Transport-Security"] = (
            "max-age=31536000; includeSubDomains"
        )

    return response


# Rate limiting middleware for chat endpoints
@app.middleware("http")
async def rate_limiting(request: Request, call_next):
    """Rate limiting for chat endpoints"""
    if request.url.path.startswith("/api/chat"):
        client_ip = request.client.host
        if not rate_limit_check(client_ip):
            return Response(
                content='{"error": "Rate limit exceeded. Please try again later."}',
                status_code=429,
                media_type="application/json",
            )

    return await call_next(request)


# Add compression
app.add_middleware(GZipMiddleware, minimum_size=1000)

# Configure CORS - strict for production
CORS_ORIGINS = os.getenv("CORS_ORIGINS", "https://linksmlm.com").split(",")
app.add_middleware(
    CORSMiddleware,
    allow_origins=[origin.strip() for origin in CORS_ORIGINS],
    allow_credentials=False,  # More secure
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["Content-Type"],
)

# Configure static file serving
DATA_DIR = os.getenv("DATA_DIR", "/data")
app.mount("/uploads", StaticFiles(directory=f"{DATA_DIR}/uploads"), name="uploads")
app.mount("/assets", StaticFiles(directory=f"{DATA_DIR}/assets"), name="assets")


# Health check endpoint
@app.get("/health")
def health_check():
    """Basic health check endpoint"""
    return {"status": "healthy", "service": "portfolio-api", "version": "2.0.0"}


# Include routers
app.include_router(health_router, prefix="/api", tags=["health"])
app.include_router(chat_router, prefix="/api", tags=["chat"])
app.include_router(avatar_router, prefix="/api", tags=["avatar"])
app.include_router(uploads_router, prefix="/api", tags=["uploads"])


# Root endpoint
@app.get("/")
def root():
    """API root endpoint"""
    return {"message": "Portfolio API v2.0.0", "docs": "/docs", "health": "/health"}


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)
