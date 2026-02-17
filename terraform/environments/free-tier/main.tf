# Sentra Free Tier Environment
# Single EC2 t2.micro with Docker Compose
# Estimated cost: $0-5/month

terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    bucket         = "sentra-terraform-state-free-sg"
    key            = "free-tier/terraform.tfstate"
    region         = "ap-southeast-1"
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
      CostCenter  = "free-tier"
    }
  }
}

locals {
  project_name = "sentra"
  environment  = "free"
  aws_region   = "ap-southeast-1"
}

# Get AWS Account ID
data "aws_caller_identity" "current" {}

# Simple VPC (Free)
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${local.project_name}-vpc-${local.environment}"
  }
}

# Internet Gateway (Free)
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.project_name}-igw-${local.environment}"
  }
}

# Public Subnet (Free)
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${local.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.project_name}-public-subnet-${local.environment}"
  }
}

# Route Table (Free)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${local.project_name}-public-rt-${local.environment}"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ECR Repositories (500MB free)
module "ecr" {
  source = "../../modules/ecr"

  project_name = local.project_name
  environment  = local.environment
}

# EC2 Free Tier Instance
module "ec2" {
  source = "../../modules/ec2-free-tier"

  project_name      = local.project_name
  environment       = local.environment
  aws_region        = local.aws_region
  vpc_id            = aws_vpc.main.id
  subnet_id         = aws_subnet.public.id
  key_name          = var.key_name
  instance_type     = "t3.micro"  # Free tier eligible
  root_volume_size  = 30          # Free tier allows 30GB EBS
  ssh_allowed_cidrs = var.ssh_allowed_cidrs
  ecr_registry      = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${local.aws_region}.amazonaws.com"
  supabase_url      = var.supabase_url
  supabase_key      = var.supabase_key
}

# GitHub Actions OIDC (Free)
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1", "1c58a3a8518e8759bf075b76b750d4f2df264fcd"]

  tags = {
    Name = "github-actions-oidc"
  }
}

# IAM Role for GitHub Actions
resource "aws_iam_role" "github_actions" {
  name = "${local.project_name}-github-actions-${local.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/*:*"
          }
        }
      }
    ]
  })

  tags = {
    Name = "${local.project_name}-github-actions-${local.environment}"
  }
}

# GitHub Actions Policy
resource "aws_iam_role_policy" "github_actions" {
  name = "${local.project_name}-github-actions-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["ssm:SendCommand", "ssm:GetCommandInvocation"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["ec2:DescribeInstances"]
        Resource = "*"
      }
    ]
  })
}
