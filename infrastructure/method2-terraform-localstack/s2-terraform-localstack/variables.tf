# LocalStack Environment Variables

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "portfolio"
}

variable "aws_region" {
  description = "AWS region (LocalStack ignores this but required for provider)"
  type        = string
  default     = "us-east-1"
}

# ============================================================================
# API Keys for Portfolio Application
# ============================================================================
# These are required for the AI chat features to work
# Set these in terraform.tfvars (or use environment variables)

variable "claude_api_key" {
  description = "Claude API key for AI chat (REQUIRED)"
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
