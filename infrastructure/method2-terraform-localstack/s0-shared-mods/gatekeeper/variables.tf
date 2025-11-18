variable "gatekeeper_version" {
  description = "Gatekeeper Helm chart version"
  type        = string
  default     = "3.18.0"
}

variable "controller_replicas" {
  description = "Number of Gatekeeper controller replicas"
  type        = number
  default     = 3
}

variable "audit_replicas" {
  description = "Number of Gatekeeper audit replicas"
  type        = number
  default     = 1
}

variable "webhook_failure_policy" {
  description = "Webhook failure policy (Ignore or Fail)"
  type        = string
  default     = "Ignore"

  validation {
    condition     = contains(["Ignore", "Fail"], var.webhook_failure_policy)
    error_message = "webhook_failure_policy must be either 'Ignore' or 'Fail'"
  }
}
