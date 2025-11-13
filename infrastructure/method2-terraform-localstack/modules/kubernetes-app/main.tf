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
        container {
          name              = "chroma"
          image             = "chromadb/chroma:0.5.18"
          image_pull_policy = "IfNotPresent"

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

          # Security: Commented out for S3 compatibility
          # security_context {
          #   allow_privilege_escalation = false
          #   run_as_non_root            = true
          #   run_as_user                = 1000
          #   capabilities {
          #     drop = ["ALL"]
          #   }
          # }
        }

        # PersistentVolumeClaim for ChromaDB data
        volume {
          name = "chroma-data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.chroma.metadata[0].name
          }
        }
      }
    }
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
          run_as_user     = 1000
          run_as_non_root = true
          fs_group        = 1000
        }

        container {
          name              = "api"
          image             = var.api_image
          image_pull_policy = "IfNotPresent"

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
            run_as_user                = 1000
            capabilities {
              drop = ["ALL"]
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
        # Security: Non-root user
        security_context {
          run_as_user     = 101  # nginx user
          run_as_non_root = true
          fs_group        = 101
        }

        container {
          name              = "ui"
          image             = var.ui_image
          image_pull_policy = "IfNotPresent"

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

          # Security: Container-level security context
          security_context {
            allow_privilege_escalation = false
            run_as_non_root            = true
            run_as_user                = 101
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
