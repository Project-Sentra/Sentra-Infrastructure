variable "aws_region" {
  type    = string
  default = "ap-southeast-1"
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
  description = "Supabase service-role key (server-side only; never ship it to clients)"
  type        = string
  sensitive   = true
}

variable "service_api_key" {
  description = "Shared secret between SentraAI and the backend (X-Service-Key). Generate with: openssl rand -hex 32"
  type        = string
  sensitive   = true
}

variable "stripe_secret_key" {
  description = "Stripe secret key for wallet top-ups (sk_test_... / sk_live_...)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "github_org" {
  description = "GitHub organization/username for OIDC"
  type        = string
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS (*.theenuka.xyz)"
  type        = string
}
