# S3: Terraform + Real AWS (PRODUCTION)
# Kubernetes + AWS services (real AWS account)

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws        = { source = "hashicorp/aws", version = "~> 5.0" }
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.23" }
    helm       = { source = "hashicorp/helm", version = "~> 2.0" }
    null       = { source = "hashicorp/null", version = "~> 3.0" }
  }
}

provider "aws" {
  region = var.aws_region
  # Uses credentials from ~/.aws/credentials or environment variables
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
# Stage 0: OPA Gatekeeper Installation
# ============================================================================

module "gatekeeper" {
  source = "../s0-shared-mods/gatekeeper"

  gatekeeper_version      = "3.18.0"
  controller_replicas     = 3
  audit_replicas          = 1
  webhook_failure_policy  = "Ignore"
}

# ============================================================================
# Stage 2: Portfolio Application
# ============================================================================

module "kubernetes_app" {
  source = "../s0-shared-mods/portfolio-app"

  namespace   = "portfolio"
  environment = "prod"

  api_image    = "ghcr.io/jimjrxieb/portfolio-api:security-v3"
  ui_image     = "ghcr.io/jimjrxieb/portfolio-ui:latest"
  chroma_image = "chromadb/chroma:0.4.18"

  claude_api_key     = var.claude_api_key
  openai_api_key     = var.openai_api_key
  elevenlabs_api_key = var.elevenlabs_api_key
  did_api_key        = var.did_api_key

  api_replicas    = 2
  ui_replicas     = 2
  chroma_replicas = 1

  depends_on = [module.opa_policies]
}

# ============================================================================
# Stage 3: AWS Resources (Production)
# ============================================================================

module "storage" {
  source       = "../s2-terraform-localstack/modules/aws-resources/storage"
  project_name = var.project_name
  environment  = "prod"
  
  use_customer_managed_encryption = true
  
  tags = {
    Environment = "prod"
    ManagedBy   = "terraform"
    CostCenter  = "portfolio"
  }
}

resource "aws_cloudwatch_event_rule" "daily_reindex" {
  name                = "${var.project_name}-daily-reindex"
  schedule_expression = "cron(0 2 * * ? *)"
  tags                = { Environment = "prod", ManagedBy = "terraform" }
}

resource "aws_cloudwatch_event_rule" "process_monitoring" {
  name                = "${var.project_name}-process-monitoring"
  schedule_expression = "rate(5 minutes)"
  tags                = { Environment = "prod", ManagedBy = "terraform" }
}

# ============================================================================
# Stage 1: OPA Gatekeeper Policies
# ============================================================================
module "opa_policies" {
  source = "../s0-shared-mods/opa-policies"

  namespace = "portfolio"
  enabled   = true

  depends_on = [module.gatekeeper]
}
