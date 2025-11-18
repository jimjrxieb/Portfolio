# OPA Gatekeeper Terraform Module
# Installs Gatekeeper via Helm chart

terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

# Create gatekeeper-system namespace
resource "kubernetes_namespace" "gatekeeper_system" {
  metadata {
    name = "gatekeeper-system"
    labels = {
      "managed-by" = "terraform"
      "app"        = "gatekeeper"
    }
  }
}

# Install Gatekeeper via Helm
resource "helm_release" "gatekeeper" {
  name       = "gatekeeper"
  repository = "https://open-policy-agent.github.io/gatekeeper/charts"
  chart      = "gatekeeper"
  version    = var.gatekeeper_version
  namespace  = kubernetes_namespace.gatekeeper_system.metadata[0].name

  values = [
    yamlencode({
      replicas = var.controller_replicas
      audit = {
        replicas = var.audit_replicas
      }

      # Enable validating webhook
      validatingWebhookConfiguration = {
        failurePolicy = var.webhook_failure_policy
      }

      # Resource limits
      controllerManager = {
        resources = {
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
          requests = {
            cpu    = "100m"
            memory = "256Mi"
          }
        }
      }

      audit = {
        resources = {
          limits = {
            cpu    = "200m"
            memory = "256Mi"
          }
          requests = {
            cpu    = "50m"
            memory = "128Mi"
          }
        }
      }
    })
  ]

  # Wait for Gatekeeper to be ready
  wait          = true
  wait_for_jobs = true
  timeout       = 600

  depends_on = [kubernetes_namespace.gatekeeper_system]
}

# Wait for Gatekeeper webhook to be ready
resource "null_resource" "wait_for_gatekeeper" {
  depends_on = [helm_release.gatekeeper]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for Gatekeeper to be ready..."
      kubectl wait --for=condition=Ready pods -l gatekeeper.sh/operation=webhook -n gatekeeper-system --timeout=300s
      echo "Gatekeeper is ready!"
    EOT
  }
}
