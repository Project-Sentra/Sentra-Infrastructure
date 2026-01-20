variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  type    = string
  default = "sentra"
}

variable "environment" {
  type    = string
  default = "free"
}

variable "key_name" {
  description = "EC2 key pair name for SSH access"
  type        = string
}

variable "ssh_allowed_cidrs" {
  description = "CIDR blocks allowed for SSH (use your IP for security)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "supabase_url" {
  description = "Supabase URL"
  type        = string
  sensitive   = true
}

variable "supabase_key" {
  description = "Supabase API Key"
  type        = string
  sensitive   = true
}

variable "github_org" {
  description = "GitHub organization/username for OIDC"
  type        = string
}
