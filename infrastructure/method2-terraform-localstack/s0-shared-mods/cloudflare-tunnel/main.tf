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
        container {
          name  = "cloudflared"
          image = "cloudflare/cloudflared:${var.cloudflared_version}"
          args  = ["tunnel", "run", "--token", "$(TUNNEL_TOKEN)"]

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

          # Note: Cloudflared doesn't expose standard health endpoints
          # The tunnel will automatically reconnect on failure
        }

        restart_policy = "Always"
      }
    }
  }

  depends_on = [kubernetes_secret.tunnel_token]
}
