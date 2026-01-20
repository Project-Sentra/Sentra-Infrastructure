# Sentra Production Environment - US East 1

terraform {
  required_version = ">= 1.6.0"

  backend "s3" {
    bucket         = "sentra-terraform-state-prod"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "sentra-terraform-locks"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

locals {
  project_name = "sentra"
  environment  = "prod"
  aws_region   = "us-east-1"
  azs          = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

# VPC - Production grade
module "vpc" {
  source = "../../modules/vpc"

  project_name         = local.project_name
  environment          = local.environment
  aws_region           = local.aws_region
  vpc_cidr             = "10.1.0.0/16"
  availability_zones   = local.azs
  enable_nat_gateway   = true
  single_nat_gateway   = false  # Multi-AZ for production
  enable_vpc_endpoints = true   # Cost-effective ECR pulls
}

# Security
module "security" {
  source = "../../modules/security"

  project_name       = local.project_name
  environment        = local.environment
  vpc_id             = module.vpc.vpc_id
  supabase_url       = var.supabase_url
  supabase_key       = var.supabase_key
  create_github_oidc = false  # Already created in dev
  github_org         = var.github_org
}

# ECR - Shared across environments
module "ecr" {
  source = "../../modules/ecr"

  project_name = local.project_name
  environment  = local.environment
}

# ALB
module "alb" {
  source = "../../modules/alb"

  project_name       = local.project_name
  environment        = local.environment
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnet_ids
  security_group_ids = [module.security.alb_security_group_id]
  certificate_arn    = var.certificate_arn
}

# ECS - Production grade
module "ecs" {
  source = "../../modules/ecs"

  project_name              = local.project_name
  environment               = local.environment
  aws_region                = local.aws_region
  private_subnet_ids        = module.vpc.private_subnet_ids
  ecs_security_group_id     = module.security.ecs_security_group_id
  use_private_subnets       = true
  use_fargate_spot          = false  # On-demand for production
  enable_container_insights = true
  log_retention_days        = 30

  # Backend - Production specs
  backend_image            = module.ecr.backend_repository_url
  backend_image_tag        = "latest"
  backend_cpu              = 512
  backend_memory           = 1024
  backend_desired_count    = 2
  backend_max_count        = 6
  backend_target_group_arn = module.alb.backend_target_group_arn

  # Frontend - Production specs
  frontend_image            = module.ecr.frontend_repository_url
  frontend_image_tag        = "latest"
  frontend_cpu              = 256
  frontend_memory           = 512
  frontend_desired_count    = 2
  frontend_target_group_arn = module.alb.frontend_target_group_arn

  # AI Service - Production specs
  ai_service_image            = module.ecr.ai_service_repository_url
  ai_service_image_tag        = "latest"
  ai_service_cpu              = 1024
  ai_service_memory           = 2048
  ai_service_desired_count    = 2
  ai_service_target_group_arn = module.alb.ai_service_target_group_arn

  # Secrets
  supabase_url_secret_arn = module.security.supabase_url_secret_arn
  supabase_key_secret_arn = module.security.supabase_key_secret_arn

  # Auto Scaling
  enable_autoscaling = true
}
