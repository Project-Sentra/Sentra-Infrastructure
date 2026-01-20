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
  default = "prod"
}

variable "supabase_url" {
  type      = string
  sensitive = true
}

variable "supabase_key" {
  type      = string
  sensitive = true
}

variable "certificate_arn" {
  type    = string
  default = ""
}

variable "github_org" {
  type    = string
  default = "*"
}
