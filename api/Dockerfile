# syntax=docker/dockerfile:1

# Use Python Alpine for smaller image size
FROM python:3.11-alpine AS base

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/app \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Install system dependencies required for Python packages
RUN apk add --no-cache \
    gcc \
    musl-dev \
    linux-headers \
    curl \
    && rm -rf /var/cache/apk/*

WORKDIR /app

# Copy and install Python dependencies
COPY api/requirements.txt /app/requirements.txt

# Install dependencies with CPU-only versions to avoid CUDA
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir \
    fastapi==0.104.1 \
    uvicorn[standard]==0.24.0 \
    pydantic[email]>=2.7.0 \
    pydantic-settings>=2.4.0 \
    python-multipart>=0.0.18 \
    python-dotenv==1.0.0 \
    httpx==0.25.2 \
    pyyaml==6.0.1 \
    openai==0.28 \
    numpy \
    chromadb==0.4.18 \
    sentence-transformers==2.2.2 \
    --extra-index-url https://download.pytorch.org/whl/cpu \
    torch --index-url https://download.pytorch.org/whl/cpu

# --- Final runtime image ---
FROM python:3.11-alpine AS run

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/app \
    DEFAULT_INTRO=/app/assets/default_intro.mp3 \
    DATA_DIR=/data

# Install minimal runtime dependencies
RUN apk add --no-cache curl

# Create non-root user for security
RUN adduser -u 10001 -D -s /bin/sh appuser

# Copy Python dependencies from builder
COPY --from=base /usr/local/lib/python3.11 /usr/local/lib/python3.11
COPY --from=base /usr/local/bin /usr/local/bin

# Copy application code
COPY api/ /app/

# Create data directory with proper permissions
RUN mkdir -p /data/uploads/audio /data/assets && \
    chown -R appuser:appuser /data /app

# Switch to non-root user
USER appuser

WORKDIR /app

# Security labels
LABEL security.scan="enabled" \
      security.non-root="true" \
      security.no-cuda="true"

EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health', timeout=5)" || exit 1

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]