# Kubernetes Application Module - Portfolio Platform
# Deploys UI, API, ChromaDB with defense-in-depth security

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

# Namespace
resource "kubernetes_namespace" "portfolio" {
  metadata {
    name = var.namespace
    labels = {
      name        = var.namespace
      environment = var.environment
      managed-by  = "terraform"
    }
  }
}

# ============================================================================
# SECRETS
# ============================================================================

resource "kubernetes_secret" "api_secrets" {
  metadata {
    name      = "portfolio-api-secrets"
    namespace = kubernetes_namespace.portfolio.metadata[0].name
  }

  data = {
    CLAUDE_API_KEY      = var.claude_api_key
    OPENAI_API_KEY      = var.openai_api_key
    ELEVENLABS_API_KEY  = var.elevenlabs_api_key
    DID_API_KEY         = var.did_api_key
  }

  type = "Opaque"
}

# ============================================================================
# CHROMADB - Vector Database
# ============================================================================

resource "kubernetes_persistent_volume_claim" "chroma" {
  metadata {
    name      = "chroma-data"
    namespace = kubernetes_namespace.portfolio.metadata[0].name
  }

  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "2Gi"
      }
    }
  }
}

resource "kubernetes_deployment" "chroma" {
  metadata {
    name      = "chroma"
    namespace = kubernetes_namespace.portfolio.metadata[0].name
    labels = {
      app = "chroma"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "chroma"
      }
    }

    template {
      metadata {
        labels = {
          app = "chroma"
        }
      }

      spec {
        # Security: Pod-level security context
        security_context {
          run_as_user     = 1000
          run_as_group    = 1000
          run_as_non_root = true
          fs_group        = 1000
          seccomp_profile {
            type = "RuntimeDefault"
          }
        }

        container {
          name              = "chroma"
          image             = var.chroma_image
          image_pull_policy = "Always"

          port {
            container_port = 8000
            name           = "http"
          }

          env {
            name  = "ANONYMIZED_TELEMETRY"
            value = "FALSE"
          }

          env {
            name  = "IS_PERSISTENT"
            value = "TRUE"
          }

          # Mount PVC at ChromaDB's default location
          volume_mount {
            name       = "chroma-data"
            mount_path = "/chroma/chroma"
          }

          # Writable tmp directory
          volume_mount {
            name       = "tmp"
            mount_path = "/tmp"
          }

          # Log config to disable file logging (readonly filesystem)
          volume_mount {
            name       = "log-config"
            mount_path = "/chroma/chromadb/log_config.yml"
            sub_path   = "log_config.yml"
          }

          # Security: Resource limits (DoS prevention)
          resources {
            requests = {
              memory = "512Mi"
              cpu    = "250m"
            }
            limits = {
              memory = "1Gi"
              cpu    = "500m"
            }
          }

          # Health checks
          liveness_probe {
            http_get {
              path = "/api/v1/heartbeat"
              port = 8000
            }
            initial_delay_seconds = 30
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/api/v1/heartbeat"
              port = 8000
            }
            initial_delay_seconds = 10
            period_seconds        = 5
          }

          # Security: Container-level security context
          security_context {
            allow_privilege_escalation = false
            run_as_non_root            = true
            run_as_user                = 1000
            read_only_root_filesystem  = true
            capabilities {
              drop = ["ALL"]
            }
          }
        }

        # PersistentVolumeClaim for ChromaDB data
        volume {
          name = "chroma-data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.chroma.metadata[0].name
          }
        }

        # Writable tmp for ChromaDB
        volume {
          name = "tmp"
          empty_dir {}
        }

        # Log config ConfigMap
        volume {
          name = "log-config"
          config_map {
            name = kubernetes_config_map.chroma_log_config.metadata[0].name
          }
        }
      }
    }
  }
}

# ChromaDB log config to disable file logging (required for readOnlyRootFilesystem)
resource "kubernetes_config_map" "chroma_log_config" {
  metadata {
    name      = "chroma-log-config"
    namespace = kubernetes_namespace.portfolio.metadata[0].name
  }

  data = {
    "log_config.yml" = <<-EOF
      version: 1
      disable_existing_loggers: false
      formatters:
        default:
          format: '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
      handlers:
        console:
          class: logging.StreamHandler
          formatter: default
          stream: ext://sys.stdout
      root:
        level: INFO
        handlers: [console]
      loggers:
        uvicorn:
          level: INFO
          handlers: [console]
          propagate: false
        uvicorn.error:
          level: INFO
          handlers: [console]
          propagate: false
        uvicorn.access:
          level: INFO
          handlers: [console]
          propagate: false
        chromadb:
          level: INFO
          handlers: [console]
          propagate: false
    EOF
  }
}

resource "kubernetes_service" "chroma" {
  metadata {
    name      = "chroma"
    namespace = kubernetes_namespace.portfolio.metadata[0].name
  }

  spec {
    selector = {
      app = "chroma"
    }

    port {
      port        = 8000
      target_port = 8000
      name        = "http"
    }

    type = "ClusterIP"
  }
}

# ============================================================================
# API - FastAPI with Security Middleware
# ============================================================================

resource "kubernetes_deployment" "api" {
  metadata {
    name      = "portfolio-api"
    namespace = kubernetes_namespace.portfolio.metadata[0].name
    labels = {
      app = "portfolio-api"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "portfolio-api"
      }
    }

    template {
      metadata {
        labels = {
          app = "portfolio-api"
        }
      }

      spec {
        # Security: Non-root user
        security_context {
          run_as_user     = 10001
          run_as_non_root = true
          fs_group        = 10001
          seccomp_profile {
            type = "RuntimeDefault"
          }
        }

        # Init container: Wait for ChromaDB
        dynamic "init_container" {
          for_each = var.enable_rag_sync ? [1] : []
          content {
            name  = "wait-for-chromadb"
            image = "busybox:1.36"

            security_context {
              run_as_non_root            = true
              run_as_user                = 10001
              allow_privilege_escalation = false
              capabilities {
                drop = ["ALL"]
              }
            }

            command = ["/bin/sh", "-c", <<-EOT
              echo "Waiting for ChromaDB..."
              for i in $(seq 1 60); do
                if wget -q -O- http://chroma:8000/api/v1/heartbeat 2>/dev/null; then
                  echo "ChromaDB ready!"
                  exit 0
                fi
                sleep 2
              done
              echo "ChromaDB timeout - continuing anyway"
              exit 0
            EOT
            ]
          }
        }

        # Init container: RAG Sync
        dynamic "init_container" {
          for_each = var.enable_rag_sync ? [1] : []
          content {
            name  = "rag-sync"
            image = "python:3.11-slim"

            security_context {
              run_as_non_root            = true
              run_as_user                = 10001
              allow_privilege_escalation = false
              capabilities {
                drop = ["ALL"]
              }
            }

            env {
              name  = "CHROMADB_URL"
              value = "http://chroma:8000"
            }
            env {
              name  = "OLLAMA_URL"
              value = "http://host.docker.internal:11434"
            }
            env {
              name  = "EMBED_MODEL"
              value = "nomic-embed-text"
            }
            env {
              name  = "HOME"
              value = "/tmp"
            }
            env {
              name  = "PIP_CACHE_DIR"
              value = "/tmp/.cache/pip"
            }

            command = ["/bin/bash", "-c", <<-EOT
              echo "=== RAG SYNC INIT ==="
              pip install --no-cache-dir --quiet chromadb==0.5.18 requests
              python3 << 'EOF'
              import os, hashlib, requests, chromadb, re
              from datetime import datetime
              from pathlib import Path

              CHROMADB_URL = os.environ.get("CHROMADB_URL")
              OLLAMA_URL = os.environ.get("OLLAMA_URL")
              EMBED_MODEL = os.environ.get("EMBED_MODEL", "nomic-embed-text")

              def get_embedding(text):
                  try:
                      r = requests.post(f"{OLLAMA_URL}/api/embeddings",
                          json={"model": EMBED_MODEL, "prompt": text}, timeout=60)
                      return r.json()["embedding"]
                  except: return [0.0] * 768

              def chunk_text(text, size=1000, overlap=200):
                  words = text.split()
                  if len(words) <= size: return [text]
                  chunks, start = [], 0
                  while start < len(words):
                      chunks.append(' '.join(words[start:start+size]))
                      start += size - overlap
                      if start + size >= len(words): break
                  return chunks

              print(f"Connecting to {CHROMADB_URL}...")
              match = re.match(r'http://([^:]+):(\d+)', CHROMADB_URL)
              client = chromadb.HttpClient(host=match.group(1), port=int(match.group(2)))

              try:
                  col = client.get_collection("portfolio_knowledge")
                  count = col.count()
                  if count > 0:
                      print(f"Collection already has {count} docs - skipping sync")
                      import sys
                      sys.exit(0)
              except Exception as e:
                  print(f"Collection check failed ({e}) - will create new")

              try: client.delete_collection("portfolio_knowledge")
              except: pass

              col = client.get_or_create_collection("portfolio_knowledge",
                  metadata={"description": "Portfolio KB", "created_at": datetime.now().isoformat()})

              RAG_DIR = Path("/rag-data")
              files = list(RAG_DIR.glob("*.md"))
              print(f"Found {len(files)} RAG files")

              total = 0
              for f in files:
                  try:
                      content = f.read_text()
                      content = ''.join(c for c in content if ord(c) >= 32 or c in '\n\t').strip()
                      if len(content) < 100: continue
                      chunks = chunk_text(content)
                      for i, chunk in enumerate(chunks):
                          doc_id = hashlib.sha256(f"{f.name}_{i}".encode()).hexdigest()
                          col.add(ids=[doc_id], embeddings=[get_embedding(chunk)],
                              documents=[chunk], metadatas=[{"source": f.name, "chunk": i}])
                          total += 1
                      print(f"  {f.name}: {len(chunks)} chunks")
                  except Exception as e: print(f"  {f.name}: ERROR {e}")

              print(f"Synced {total} docs to ChromaDB")
              EOF
            EOT
            ]

            resources {
              requests = {
                cpu    = "100m"
                memory = "256Mi"
              }
              limits = {
                cpu    = "500m"
                memory = "512Mi"
              }
            }

            volume_mount {
              name       = "rag-data"
              mount_path = "/rag-data"
              read_only  = true
            }
          }
        }

        # Init container: Pre-download ChromaDB embedding model (ONNX, CPU-only)
        dynamic "init_container" {
          for_each = var.enable_rag_sync ? [1] : []
          content {
            name  = "download-embedding-model"
            image = "python:3.11-slim"

            security_context {
              run_as_non_root            = true
              run_as_user                = 10001
              allow_privilege_escalation = false
              capabilities {
                drop = ["ALL"]
              }
            }

            env {
              name  = "HOME"
              value = "/"
            }

            env {
              name  = "PYTHONUSERBASE"
              value = "/.cache/pip"
            }

            command = ["/bin/bash", "-c", <<-EOT
              echo "=== PRE-DOWNLOADING CHROMADB EMBEDDING MODEL ==="
              mkdir -p /.cache/pip/lib/python3.11/site-packages
              pip install --user --no-cache-dir --quiet chromadb==0.5.18 onnxruntime
              export PYTHONPATH=/.cache/pip/lib/python3.11/site-packages:$PYTHONPATH
              python3 << 'EOF'
import sys
sys.path.insert(0, '/.cache/pip/lib/python3.11/site-packages')
import os
os.environ['HOME'] = '/'
print("Initializing ChromaDB default embedding function...")
try:
    from chromadb.utils.embedding_functions import ONNXMiniLM_L6_V2
    ef = ONNXMiniLM_L6_V2()
    # Trigger model download by embedding a test string
    result = ef(["test"])
    print(f"Model downloaded successfully! Test embedding dim: {len(result[0])}")
except Exception as e:
    print(f"Warning: Could not pre-download model: {e}")
    print("RAG will still work but first query may be slow")
EOF
              echo "=== EMBEDDING MODEL READY ==="
            EOT
            ]

            volume_mount {
              name       = "cache"
              mount_path = "/.cache"
            }
          }
        }

        container {
          name              = "api"
          image             = var.api_image
          image_pull_policy = "Always"

          port {
            container_port = 8000
            name           = "http"
          }

          env {
            name  = "CHROMA_HOST"
            value = "chroma"
          }

          env {
            name  = "CHROMA_PORT"
            value = "8000"
          }

          # Full ChromaDB URL for rag_engine.py
          env {
            name  = "CHROMA_URL"
            value = "http://chroma:8000"
          }

          env {
            name  = "DATA_DIR"
            value = "/data"
          }

          env {
            name  = "EMBEDDING_MODEL"
            value = "nomic-embed-text"
          }

          env {
            name  = "EMBED_MODEL"
            value = "nomic-embed-text"
          }

          env {
            name  = "OLLAMA_URL"
            value = "http://host.docker.internal:11434"
          }

          # HOME for ChromaDB embedding model cache (pre-downloaded by init container)
          env {
            name  = "HOME"
            value = "/"
          }

          # Security: API Keys from Secrets
          env {
            name = "CLAUDE_API_KEY"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.api_secrets.metadata[0].name
                key  = "CLAUDE_API_KEY"
              }
            }
          }

          env {
            name = "OPENAI_API_KEY"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.api_secrets.metadata[0].name
                key  = "OPENAI_API_KEY"
              }
            }
          }

          env {
            name = "ELEVENLABS_API_KEY"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.api_secrets.metadata[0].name
                key  = "ELEVENLABS_API_KEY"
              }
            }
          }

          env {
            name = "DID_API_KEY"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.api_secrets.metadata[0].name
                key  = "DID_API_KEY"
              }
            }
          }

          # Security: Resource limits
          resources {
            requests = {
              memory = "512Mi"
              cpu    = "250m"
            }
            limits = {
              memory = "2Gi"
              cpu    = "1000m"
            }
          }

          # Health checks
          liveness_probe {
            http_get {
              path = "/health"
              port = 8000
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 5
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 8000
            }
            initial_delay_seconds = 10
            period_seconds        = 5
            timeout_seconds       = 3
            failure_threshold     = 3
          }

          # Security: Container-level security context
          security_context {
            allow_privilege_escalation = false
            run_as_non_root            = true
            run_as_user                = 10001
            read_only_root_filesystem  = true
            capabilities {
              drop = ["ALL"]
            }
          }

          # Volume mounts for API container
          volume_mount {
            name       = "data"
            mount_path = "/data"
          }

          volume_mount {
            name       = "tmp"
            mount_path = "/tmp"
          }

          volume_mount {
            name       = "cache"
            mount_path = "/.cache"
          }
        }

        # Volumes
        volume {
          name = "data"
          empty_dir {}
        }

        volume {
          name = "tmp"
          empty_dir {}
        }

        volume {
          name = "cache"
          empty_dir {}
        }

        dynamic "volume" {
          for_each = var.enable_rag_sync ? [1] : []
          content {
            name = "rag-data"
            config_map {
              name = var.rag_configmap_name
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "api" {
  metadata {
    name      = "portfolio-api"
    namespace = kubernetes_namespace.portfolio.metadata[0].name
  }

  spec {
    selector = {
      app = "portfolio-api"
    }

    port {
      port        = 8000
      target_port = 8000
      name        = "http"
    }

    type = "ClusterIP"
  }
}

# ============================================================================
# UI - React Frontend
# ============================================================================

resource "kubernetes_deployment" "ui" {
  metadata {
    name      = "portfolio-ui"
    namespace = kubernetes_namespace.portfolio.metadata[0].name
    labels = {
      app = "portfolio-ui"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "portfolio-ui"
      }
    }

    template {
      metadata {
        labels = {
          app = "portfolio-ui"
        }
      }

      spec {
        # Security: Non-root user with seccompProfile
        security_context {
          run_as_user     = 101  # nginx user
          run_as_group    = 101
          run_as_non_root = true
          fs_group        = 101
          seccomp_profile {
            type = "RuntimeDefault"
          }
        }

        container {
          name              = "ui"
          image             = var.ui_image
          image_pull_policy = "Always"

          port {
            container_port = 80
            name           = "http"
          }

          env {
            name  = "VITE_API_BASE_URL"
            value = ""
          }

          # Security: Resource limits
          resources {
            requests = {
              memory = "128Mi"
              cpu    = "100m"
            }
            limits = {
              memory = "256Mi"
              cpu    = "200m"
            }
          }

          # Health checks
          liveness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 5
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 10
            period_seconds        = 5
            timeout_seconds       = 3
          }

          # Volume mounts for nginx cache (writable by UID 101)
          volume_mount {
            name       = "nginx-cache"
            mount_path = "/var/cache/nginx"
          }

          volume_mount {
            name       = "nginx-run"
            mount_path = "/var/run"
          }

          # Writable tmp directory
          volume_mount {
            name       = "tmp"
            mount_path = "/tmp"
          }

          # Security: Container-level security context with readOnlyRootFilesystem
          security_context {
            allow_privilege_escalation = false
            run_as_non_root            = true
            run_as_user                = 101
            read_only_root_filesystem  = true
            capabilities {
              drop = ["ALL"]
            }
          }
        }

        # Volumes for nginx writable directories
        volume {
          name = "nginx-cache"
          empty_dir {}
        }

        volume {
          name = "nginx-run"
          empty_dir {}
        }

        volume {
          name = "tmp"
          empty_dir {}
        }
      }
    }
  }
}

resource "kubernetes_service" "ui" {
  metadata {
    name      = "portfolio-ui"
    namespace = kubernetes_namespace.portfolio.metadata[0].name
  }

  spec {
    selector = {
      app = "portfolio-ui"
    }

    port {
      port        = 80
      target_port = 80
      name        = "http"
    }

    type = "ClusterIP"
  }
}
