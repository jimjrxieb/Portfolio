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

# Install dependencies - use requirements.txt for consistent builds
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r /app/requirements.txt

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