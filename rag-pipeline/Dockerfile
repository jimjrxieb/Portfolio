FROM jupyter/datascience-notebook:latest

USER root
# Security: Switch to non-root user
RUN adduser --disabled-password --gecos '' appuser
USER appuser

# Install additional system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

USER $NB_UID

# Install Python packages for RAG pipeline
COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt

# Copy RAG pipeline code
COPY . /app/
WORKDIR /app

# Create directories
RUN mkdir -p /app/notebooks /app/knowledge /app/chroma

# Copy Jupyter configuration
COPY jupyter_lab_config.py /home/$NB_USER/.jupyter/

EXPOSE 8888 8000

# Start both Jupyter Lab and RAG API
CMD ["bash", "start-services.sh"]