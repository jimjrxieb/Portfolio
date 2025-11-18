# S1: Terraform Simple (Kubernetes Only)
# Self-contained deployment: Gatekeeper + OPA Policies + Portfolio App

terraform {
  required_version = ">= 1.0"
  required_providers {
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.23" }
    helm       = { source = "hashicorp/helm", version = "~> 2.0" }
    null       = { source = "hashicorp/null", version = "~> 3.0" }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

# ============================================================================
# Stage 1: OPA Gatekeeper Installation
# ============================================================================
# Gatekeeper must be installed first to enforce security policies

module "gatekeeper" {
  source = "../s0-shared-mods/gatekeeper"

  gatekeeper_version      = "3.18.0"
  controller_replicas     = 3
  audit_replicas          = 1
  webhook_failure_policy  = "Ignore"
}

# ============================================================================
# Stage 2: OPA Security Policies
# ============================================================================
# Deploy ConstraintTemplates and Constraints after Gatekeeper is ready

module "opa_policies" {
  source = "../s0-shared-mods/opa-policies"

  namespace = "portfolio"
  enabled   = true

  # Policies require Gatekeeper to be fully operational
  depends_on = [module.gatekeeper]
}

# ============================================================================
# Stage 3: Portfolio Application
# ============================================================================
# Deploy application pods - they will be validated by OPA policies

module "portfolio" {
  source = "../s0-shared-mods/portfolio-app"

  namespace   = "portfolio"
  environment = "simple"

  api_image    = "ghcr.io/jimjrxieb/portfolio-api:security-v3"
  ui_image     = "ghcr.io/jimjrxieb/portfolio-ui:vite-fix"
  chroma_image = "chromadb/chroma:0.4.18"

  claude_api_key     = var.claude_api_key
  openai_api_key     = var.openai_api_key
  elevenlabs_api_key = var.elevenlabs_api_key
  did_api_key        = var.did_api_key

  api_replicas    = 1
  ui_replicas     = 1
  chroma_replicas = 1

  # Application deploys after security policies are in place
  depends_on = [module.opa_policies]
}

# ============================================================================
# Stage 4: Cloudflare Tunnel (Optional)
# ============================================================================
# Exposes the application publicly via Cloudflare Zero Trust Tunnel

module "cloudflare_tunnel" {
  count  = var.enable_cloudflare_tunnel && var.cloudflare_tunnel_token != "" ? 1 : 0
  source = "../s0-shared-mods/cloudflare-tunnel"

  namespace            = "cloudflare"
  tunnel_token         = var.cloudflare_tunnel_token
  cloudflared_version  = "latest"
  replicas             = 1

  # Tunnel deploys after application is ready
  depends_on = [module.portfolio]
}
