variable "claude_api_key" {
  type      = string
  sensitive = true
}

variable "openai_api_key" {
  type      = string
  sensitive = true
  default   = ""
}

variable "elevenlabs_api_key" {
  type      = string
  sensitive = true
  default   = ""
}

variable "did_api_key" {
  type      = string
  sensitive = true
  default   = ""
}

variable "cloudflare_tunnel_token" {
  type        = string
  sensitive   = true
  description = "Cloudflare Tunnel token for public access"
  default     = ""
}

variable "enable_cloudflare_tunnel" {
  type        = bool
  description = "Enable Cloudflare Tunnel for public access"
  default     = false
}
