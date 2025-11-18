output "namespace" {
  description = "Gatekeeper namespace name"
  value       = kubernetes_namespace.gatekeeper_system.metadata[0].name
}

output "release_name" {
  description = "Helm release name"
  value       = helm_release.gatekeeper.name
}

output "release_version" {
  description = "Deployed Gatekeeper version"
  value       = helm_release.gatekeeper.version
}

output "release_status" {
  description = "Helm release status"
  value       = helm_release.gatekeeper.status
}
