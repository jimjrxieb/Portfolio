variable "project_name" {
  type    = string
  default = "portfolio"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

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
