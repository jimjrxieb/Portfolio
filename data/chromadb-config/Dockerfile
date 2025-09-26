FROM chromadb/chroma:latest

# Add health check endpoint
COPY health-check.py /app/health-check.py

# Install curl for health checks
USER root
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Create chroma user and group if they don't exist
RUN groupadd -r chroma || true
RUN useradd -r -g chroma -s /bin/false chroma || true

# Set permissions for directories that exist
RUN chown -R chroma:chroma /app 2>/dev/null || true
RUN mkdir -p /chroma && chown -R chroma:chroma /chroma 2>/dev/null || true

USER chroma

EXPOSE 8000

CMD ["chroma", "run", "--host", "0.0.0.0", "--port", "8000"]