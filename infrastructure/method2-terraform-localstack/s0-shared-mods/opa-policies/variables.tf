variable "namespace" {
  description = "Namespace to deploy OPA constraints to"
  type        = string
  default     = "portfolio"
}

variable "enabled" {
  description = "Enable OPA policy deployment"
  type        = bool
  default     = true
}
