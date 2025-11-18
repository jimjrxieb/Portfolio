# Outputs for Kubernetes Application Module

output "namespace" {
  description = "Kubernetes namespace name"
  value       = kubernetes_namespace.portfolio.metadata[0].name
}

output "ui_service_name" {
  description = "UI service name"
  value       = kubernetes_service.ui.metadata[0].name
}

output "ui_service_port" {
  description = "UI service port"
  value       = kubernetes_service.ui.spec[0].port[0].port
}

output "ui_node_port" {
  description = "UI NodePort (for local access)"
  value       = kubernetes_service.ui.spec[0].port[0].node_port
}

output "api_service_name" {
  description = "API service name"
  value       = kubernetes_service.api.metadata[0].name
}

output "api_service_port" {
  description = "API service port"
  value       = kubernetes_service.api.spec[0].port[0].port
}

output "chroma_service_name" {
  description = "ChromaDB service name"
  value       = kubernetes_service.chroma.metadata[0].name
}

output "chroma_service_port" {
  description = "ChromaDB service port"
  value       = kubernetes_service.chroma.spec[0].port[0].port
}

output "network_policies" {
  description = "List of network policies deployed"
  value = [
    kubernetes_network_policy.default_deny_all.metadata[0].name,
    kubernetes_network_policy.allow_dns.metadata[0].name,
    kubernetes_network_policy.ui_ingress.metadata[0].name,
    kubernetes_network_policy.api_ingress.metadata[0].name,
    kubernetes_network_policy.api_to_chroma.metadata[0].name,
    kubernetes_network_policy.chroma_ingress.metadata[0].name,
  ]
}

output "deployments" {
  description = "List of deployments"
  value = {
    ui = {
      name     = kubernetes_deployment.ui.metadata[0].name
      replicas = kubernetes_deployment.ui.spec[0].replicas
      image    = var.ui_image
    }
    api = {
      name     = kubernetes_deployment.api.metadata[0].name
      replicas = kubernetes_deployment.api.spec[0].replicas
      image    = var.api_image
    }
    chroma = {
      name     = kubernetes_deployment.chroma.metadata[0].name
      replicas = kubernetes_deployment.chroma.spec[0].replicas
      image    = var.chroma_image
    }
  }
}

output "security_summary" {
  description = "Security controls deployed"
  value = {
    network_policies     = length([
      kubernetes_network_policy.default_deny_all.metadata[0].name,
      kubernetes_network_policy.allow_dns.metadata[0].name,
      kubernetes_network_policy.ui_ingress.metadata[0].name,
      kubernetes_network_policy.api_ingress.metadata[0].name,
      kubernetes_network_policy.api_to_chroma.metadata[0].name,
      kubernetes_network_policy.chroma_ingress.metadata[0].name,
    ])
    non_root_containers  = true
    resource_limits      = true
    secrets_management   = true
    health_checks        = true
    chroma_isolation     = "no external egress (DNS only)"
  }
}
