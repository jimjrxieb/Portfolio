output "policy_files_deployed" {
  description = "Number of OPA policy files deployed"
  value       = length(local.gk_policy_files)
}

output "policy_files" {
  description = "List of deployed OPA policy files"
  value       = local.gk_policy_files
}

output "policies_enabled" {
  description = "Whether OPA policies are enabled"
  value       = var.enabled
}

output "policies_hash" {
  description = "Hash of all policy files for change detection"
  value       = var.enabled ? sha256(join("", [for file in local.gk_policy_files : filesha256("${local.gk_policies_base}/${file}")])) : ""
}
