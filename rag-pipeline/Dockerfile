# RAG Pipeline Ingestion Container
FROM python:3.11-slim

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/app

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copy ingestion script
COPY ingest_to_chroma.py .

# Create non-root user for security
RUN useradd -m -r -u 1000 appuser && \
    chown -R appuser:appuser /app

# Create data directories
RUN mkdir -p /app/new-rag-data /app/processed-rag-data && \
    chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Run ingestion pipeline
CMD ["python3", "ingest_to_chroma.py"]