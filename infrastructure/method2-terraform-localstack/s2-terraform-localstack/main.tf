# S2: Terraform + LocalStack (DEV)
# Kubernetes + AWS services (simulated locally)

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
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true

  endpoints {
    s3         = "http://localhost:4566"
    dynamodb   = "http://localhost:4566"
    sqs        = "http://localhost:4566"
    lambda     = "http://localhost:4566"
    cloudwatch = "http://localhost:4566"
    logs       = "http://localhost:4566"
    events     = "http://localhost:4566"
    iam        = "http://localhost:4566"
    sts        = "http://localhost:4566"
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
  environment = "dev"

  # Use versioned images from CI/CD pipeline
  # Keep these in sync with running images (kubectl get pods -n portfolio -o wide)
  api_image    = "ghcr.io/jimjrxieb/portfolio-api:v1.0.7"
  ui_image     = "ghcr.io/jimjrxieb/portfolio-ui:v1.0.3"
  chroma_image = "chromadb/chroma:0.5.18"

  claude_api_key     = var.claude_api_key
  openai_api_key     = var.openai_api_key
  elevenlabs_api_key = var.elevenlabs_api_key
  did_api_key        = var.did_api_key

  api_replicas    = 1
  ui_replicas     = 1
  chroma_replicas = 1

  # Enable RAG sync init containers
  enable_rag_sync    = true
  rag_configmap_name = "rag-data"

  depends_on = [module.opa_policies]
}

# ============================================================================
# Stage 3: AWS Resources (LocalStack)
# ============================================================================

module "storage" {
  source       = "./modules/aws-resources/storage"
  project_name = var.project_name
  environment  = "dev"
  tags         = { Environment = "dev", ManagedBy = "terraform" }
}

resource "aws_cloudwatch_event_rule" "daily_reindex" {
  name                = "${var.project_name}-daily-reindex"
  schedule_expression = "cron(0 2 * * ? *)"
  tags                = { Environment = "dev", ManagedBy = "terraform" }
}

resource "aws_cloudwatch_event_rule" "process_monitoring" {
  name                = "${var.project_name}-process-monitoring"
  schedule_expression = "rate(5 minutes)"
  tags                = { Environment = "dev", ManagedBy = "terraform" }
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
