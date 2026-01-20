variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "ecs_security_group_id" {
  type = string
}

variable "use_private_subnets" {
  type    = bool
  default = true
}

variable "use_fargate_spot" {
  type    = bool
  default = false
}

variable "enable_container_insights" {
  type    = bool
  default = true
}

variable "log_retention_days" {
  type    = number
  default = 30
}

# Backend Configuration
variable "backend_image" {
  type = string
}

variable "backend_image_tag" {
  type    = string
  default = "latest"
}

variable "backend_cpu" {
  type    = number
  default = 256
}

variable "backend_memory" {
  type    = number
  default = 512
}

variable "backend_desired_count" {
  type    = number
  default = 1
}

variable "backend_max_count" {
  type    = number
  default = 3
}

variable "backend_target_group_arn" {
  type = string
}

# Frontend Configuration
variable "frontend_image" {
  type = string
}

variable "frontend_image_tag" {
  type    = string
  default = "latest"
}

variable "frontend_cpu" {
  type    = number
  default = 256
}

variable "frontend_memory" {
  type    = number
  default = 512
}

variable "frontend_desired_count" {
  type    = number
  default = 1
}

variable "frontend_target_group_arn" {
  type = string
}

# AI Service Configuration
variable "ai_service_image" {
  type = string
}

variable "ai_service_image_tag" {
  type    = string
  default = "latest"
}

variable "ai_service_cpu" {
  type    = number
  default = 512
}

variable "ai_service_memory" {
  type    = number
  default = 1024
}

variable "ai_service_desired_count" {
  type    = number
  default = 1
}

variable "ai_service_target_group_arn" {
  type = string
}

# Secrets
variable "supabase_url_secret_arn" {
  type = string
}

variable "supabase_key_secret_arn" {
  type = string
}

# Auto Scaling
variable "enable_autoscaling" {
  type    = bool
  default = false
}
