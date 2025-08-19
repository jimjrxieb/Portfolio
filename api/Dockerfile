# syntax=docker/dockerfile:1

FROM python:3.11-slim AS base
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /app

# System deps minimal with --mount cache  
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    curl build-essential && \
    rm -rf /var/lib/apt/lists/*

# Install dependencies in layers for better caching
# Layer 1: Core FastAPI dependencies (change rarely)
COPY api/requirements-base.txt /app/requirements-base.txt
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --upgrade pip && \
    pip install -r /app/requirements-base.txt

# Layer 2: External services (change occasionally)  
COPY api/requirements-external.txt /app/requirements-external.txt
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r /app/requirements-external.txt

# Layer 3: Heavy ML dependencies (change rarely but big downloads)
COPY api/requirements-ml.txt /app/requirements-ml.txt  
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r /app/requirements-ml.txt

# Layer 4: Legacy requirements (for compatibility)
COPY api/requirements.txt /app/requirements.txt
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r /app/requirements.txt

# --- Final runtime image ---
FROM python:3.11-slim AS run
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /app

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends curl \
 && rm -rf /var/lib/apt/lists/*

# Non-root user for security with hardened settings
RUN useradd -u 10001 -m -r -s /sbin/nologin -c "Application User" appuser && \
    mkdir -p /home/appuser && \
    chown appuser:appuser /home/appuser

# Copy Python dependencies from builder
COPY --from=base /usr/local/lib/python3.11 /usr/local/lib/python3.11
COPY --from=base /usr/local/bin /usr/local/bin

# Copy ONLY the clean API structure and assets
COPY api/ /app/
COPY chat/ /app/chat/

# Environment defaults
ENV DEFAULT_INTRO=/app/assets/default_intro.mp3
ENV DATA_DIR=/data
ENV PYTHONPATH=/app

# Create data directory with proper permissions and security hardening
RUN mkdir -p /data/uploads/audio /data/assets /tmp/app && \
    chown -R appuser:appuser /data /app /tmp/app && \
    chmod -R 750 /data /app && \
    chmod 1777 /tmp/app

# Security: Remove unnecessary packages and files
RUN apt-get remove --purge -y curl && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Switch to non-root user
USER appuser

# Set secure working directory
WORKDIR /app

# Security labels
LABEL security.scan="enabled" \
      security.non-root="true" \
      security.capabilities="none"

EXPOSE 8000

# Health check using Python instead of curl for smaller image
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health', timeout=5)" || exit 1

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]