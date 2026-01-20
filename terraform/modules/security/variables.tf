variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "supabase_url" {
  type      = string
  sensitive = true
}

variable "supabase_key" {
  type      = string
  sensitive = true
}

variable "create_github_oidc" {
  type    = bool
  default = true
}

variable "github_org" {
  type    = string
  default = "*"
}
