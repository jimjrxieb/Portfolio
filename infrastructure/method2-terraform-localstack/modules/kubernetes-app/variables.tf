# Variables for Kubernetes Application Module

variable "namespace" {
  description = "Kubernetes namespace for portfolio application"
  type        = string
  default     = "portfolio"
}

variable "environment" {
  description = "Environment name (localstack, dev, prod)"
  type        = string
  default     = "localstack"
}

# ============================================================================
# Container Images
# ============================================================================

variable "api_image" {
  description = "Docker image for portfolio API"
  type        = string
  default     = "ghcr.io/jimjrxieb/portfolio-api:security-v3"
}

variable "ui_image" {
  description = "Docker image for portfolio UI"
  type        = string
  default     = "ghcr.io/jimjrxieb/portfolio-ui:latest"
}

variable "chroma_image" {
  description = "Docker image for ChromaDB"
  type        = string
  default     = "chromadb/chroma:0.4.18"
}

# ============================================================================
# API Configuration
# ============================================================================

variable "api_base_url" {
  description = "Base URL for API (used by UI)"
  type        = string
  default     = "http://portfolio.localtest.me/api"
}

# ============================================================================
# Secrets - API Keys
# ============================================================================

variable "claude_api_key" {
  description = "Claude API key for AI chat"
  type        = string
  sensitive   = true
}

variable "openai_api_key" {
  description = "OpenAI API key (optional)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "elevenlabs_api_key" {
  description = "ElevenLabs API key for voice synthesis (optional)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "did_api_key" {
  description = "D-ID API key for avatar (optional)"
  type        = string
  sensitive   = true
  default     = ""
}

# ============================================================================
# Resource Limits
# ============================================================================

variable "api_cpu_request" {
  description = "CPU request for API pods"
  type        = string
  default     = "250m"
}

variable "api_memory_request" {
  description = "Memory request for API pods"
  type        = string
  default     = "512Mi"
}

variable "api_cpu_limit" {
  description = "CPU limit for API pods"
  type        = string
  default     = "1000m"
}

variable "api_memory_limit" {
  description = "Memory limit for API pods"
  type        = string
  default     = "2Gi"
}

variable "chroma_cpu_request" {
  description = "CPU request for ChromaDB pods"
  type        = string
  default     = "250m"
}

variable "chroma_memory_request" {
  description = "Memory request for ChromaDB pods"
  type        = string
  default     = "512Mi"
}

variable "chroma_cpu_limit" {
  description = "CPU limit for ChromaDB pods"
  type        = string
  default     = "500m"
}

variable "chroma_memory_limit" {
  description = "Memory limit for ChromaDB pods"
  type        = string
  default     = "1Gi"
}

variable "ui_cpu_request" {
  description = "CPU request for UI pods"
  type        = string
  default     = "100m"
}

variable "ui_memory_request" {
  description = "Memory request for UI pods"
  type        = string
  default     = "128Mi"
}

variable "ui_cpu_limit" {
  description = "CPU limit for UI pods"
  type        = string
  default     = "200m"
}

variable "ui_memory_limit" {
  description = "Memory limit for UI pods"
  type        = string
  default     = "256Mi"
}

# ============================================================================
# Replica Counts
# ============================================================================

variable "api_replicas" {
  description = "Number of API replicas"
  type        = number
  default     = 1
}

variable "ui_replicas" {
  description = "Number of UI replicas"
  type        = number
  default     = 1
}

variable "chroma_replicas" {
  description = "Number of ChromaDB replicas"
  type        = number
  default     = 1
}
