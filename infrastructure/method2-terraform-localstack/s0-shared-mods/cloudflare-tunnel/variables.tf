variable "namespace" {
  description = "Kubernetes namespace for Cloudflare Tunnel"
  type        = string
  default     = "cloudflare"
}

variable "tunnel_token" {
  description = "Cloudflare Tunnel token"
  type        = string
  sensitive   = true
}

variable "cloudflared_version" {
  description = "cloudflared container image version"
  type        = string
  default     = "latest"
}

variable "replicas" {
  description = "Number of cloudflared replicas"
  type        = number
  default     = 1
}

variable "resource_limits" {
  description = "Resource limits for cloudflared"
  type = object({
    cpu    = string
    memory = string
  })
  default = {
    cpu    = "200m"
    memory = "256Mi"
  }
}

variable "resource_requests" {
  description = "Resource requests for cloudflared"
  type = object({
    cpu    = string
    memory = string
  })
  default = {
    cpu    = "100m"
    memory = "128Mi"
  }
}
