# syntax=docker/dockerfile:1

FROM python:3.11-slim AS base
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /app

# System deps minimal  
RUN apt-get update && apt-get install -y --no-install-recommends curl build-essential \
 && rm -rf /var/lib/apt/lists/*

# Install Python dependencies first for layer caching
COPY api/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

# --- Final runtime image ---
FROM python:3.11-slim AS run
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /app

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends curl \
 && rm -rf /var/lib/apt/lists/*

# Non-root user for security
RUN useradd -u 10001 -m -r appuser

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

# Create data directory with proper permissions
RUN mkdir -p /data/uploads/audio /data/assets && \
    chown -R appuser:appuser /data /app

USER appuser
EXPOSE 8000

# Health check using Python instead of curl for smaller image
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health', timeout=5)" || exit 1

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]