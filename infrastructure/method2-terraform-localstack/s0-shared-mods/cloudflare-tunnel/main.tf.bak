# Cloudflare Tunnel (cloudflared) Terraform Module
# Deploys cloudflared to expose services publicly via Cloudflare

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}

# Create namespace for cloudflare tunnel
resource "kubernetes_namespace" "cloudflare" {
  metadata {
    name = var.namespace
    labels = {
      "managed-by" = "terraform"
      "app"        = "cloudflare-tunnel"
    }
  }
}

# Secret for tunnel token
resource "kubernetes_secret" "tunnel_token" {
  metadata {
    name      = "cloudflare-tunnel-token"
    namespace = kubernetes_namespace.cloudflare.metadata[0].name
  }

  data = {
    token = var.tunnel_token
  }

  type = "Opaque"
}

# Deployment for cloudflared
resource "kubernetes_deployment" "cloudflared" {
  metadata {
    name      = "cloudflared"
    namespace = kubernetes_namespace.cloudflare.metadata[0].name
    labels = {
      app = "cloudflared"
    }
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = {
        app = "cloudflared"
      }
    }

    template {
      metadata {
        labels = {
          app = "cloudflared"
        }
      }

      spec {
        # Security: Pod-level security context
        security_context {
          run_as_user     = 65532  # nonroot user
          run_as_group    = 65532
          run_as_non_root = true
          fs_group        = 65532
          seccomp_profile {
            type = "RuntimeDefault"
          }
        }

        container {
          name              = "cloudflared"
          image             = "cloudflare/cloudflared:${var.cloudflared_version}"
          image_pull_policy = "Always"
          args              = ["tunnel", "--no-autoupdate", "run", "--token", "$(TUNNEL_TOKEN)"]

          env {
            name = "TUNNEL_TOKEN"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.tunnel_token.metadata[0].name
                key  = "token"
              }
            }
          }

          resources {
            limits = {
              cpu    = var.resource_limits.cpu
              memory = var.resource_limits.memory
            }
            requests = {
              cpu    = var.resource_requests.cpu
              memory = var.resource_requests.memory
            }
          }

          # Health checks - cloudflared exposes metrics on port 2000
          liveness_probe {
            http_get {
              path = "/ready"
              port = 2000
            }
            initial_delay_seconds = 10
            period_seconds        = 10
            failure_threshold     = 3
          }

          readiness_probe {
            http_get {
              path = "/ready"
              port = 2000
            }
            initial_delay_seconds = 5
            period_seconds        = 5
            failure_threshold     = 3
          }

          # Security: Container-level security context
          security_context {
            allow_privilege_escalation = false
            run_as_non_root            = true
            run_as_user                = 65532
            read_only_root_filesystem  = true
            capabilities {
              drop = ["ALL"]
            }
          }

          # Writable directories for cloudflared
          volume_mount {
            name       = "tmp"
            mount_path = "/tmp"
          }
        }

        # Volumes
        volume {
          name = "tmp"
          empty_dir {}
        }

        restart_policy = "Always"
      }
    }
  }

  depends_on = [kubernetes_secret.tunnel_token]
}
