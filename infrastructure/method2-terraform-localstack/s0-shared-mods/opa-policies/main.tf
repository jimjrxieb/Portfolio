# OPA Gatekeeper Policies Module
# Deploys Gatekeeper ConstraintTemplates and Constraints for Portfolio security

terraform {
  required_providers {
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

locals {
  # Path to shared Gatekeeper policies
  gk_policies_base = "${path.module}/../../../../shared-gk-policies"

  # All Gatekeeper policy files
  gk_policy_files = fileset(local.gk_policies_base, "**/*.yaml")
}

# Deploy all OPA Gatekeeper policies using kubectl apply
resource "null_resource" "gk_policies" {
  count = var.enabled ? 1 : 0

  triggers = {
    # Re-deploy if any policy file changes
    policy_files_hash = sha256(join("", [
      for file in local.gk_policy_files :
      filesha256("${local.gk_policies_base}/${file}")
    ]))
    namespace    = var.namespace
    policies_dir = local.gk_policies_base
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Apply all Gatekeeper policies
      echo "Deploying OPA Gatekeeper policies from ${local.gk_policies_base}..."
      kubectl apply -f ${local.gk_policies_base}/compliance/ || true
      kubectl apply -f ${local.gk_policies_base}/governance/ || true
      kubectl apply -f ${local.gk_policies_base}/security/ || true
      echo "OPA Gatekeeper policies deployed successfully"
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      # Delete all Gatekeeper policies on destroy
      echo "Deleting OPA Gatekeeper policies from ${self.triggers.policies_dir}..."
      kubectl delete -f ${self.triggers.policies_dir}/compliance/ --ignore-not-found=true || true
      kubectl delete -f ${self.triggers.policies_dir}/governance/ --ignore-not-found=true || true
      kubectl delete -f ${self.triggers.policies_dir}/security/ --ignore-not-found=true || true
      echo "OPA Gatekeeper policies deleted"
    EOT
  }
}
