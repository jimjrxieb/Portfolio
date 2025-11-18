output "namespace" {
  description = "Cloudflare Tunnel namespace"
  value       = kubernetes_namespace.cloudflare.metadata[0].name
}

output "deployment_name" {
  description = "Cloudflare Tunnel deployment name"
  value       = kubernetes_deployment.cloudflared.metadata[0].name
}

output "replicas" {
  description = "Number of cloudflared replicas"
  value       = var.replicas
}
