#!/bin/bash
# Deploy script for Sentra services

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
PROJECT_NAME="sentra"
AWS_REGION="${AWS_REGION:-us-east-1}"
ENVIRONMENT="${1:-dev}"
SERVICE="${2:-all}"

echo -e "${GREEN}=== Sentra Deployment ===${NC}"
echo -e "Environment: ${YELLOW}${ENVIRONMENT}${NC}"
echo -e "Service: ${YELLOW}${SERVICE}${NC}"
echo ""

# Get AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

# Login to ECR
echo -e "${GREEN}Logging in to ECR...${NC}"
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_REGISTRY"

# Function to build and push
build_and_push() {
    local service=$1
    local context=$2
    local tag="${GITHUB_SHA:-$(git rev-parse --short HEAD)}-$(date +%Y%m%d%H%M%S)"

    echo -e "${GREEN}Building ${service}...${NC}"
    docker build -t "${ECR_REGISTRY}/${PROJECT_NAME}-${service}:${tag}" \
                 -t "${ECR_REGISTRY}/${PROJECT_NAME}-${service}:latest" \
                 "$context"

    echo -e "${GREEN}Pushing ${service}...${NC}"
    docker push "${ECR_REGISTRY}/${PROJECT_NAME}-${service}:${tag}"
    docker push "${ECR_REGISTRY}/${PROJECT_NAME}-${service}:latest"

    echo "$tag"
}

# Function to update ECS service
update_ecs_service() {
    local service=$1
    local image_tag=$2

    echo -e "${GREEN}Updating ECS service: ${service}...${NC}"
    aws ecs update-service \
        --cluster "${PROJECT_NAME}-cluster-${ENVIRONMENT}" \
        --service "${PROJECT_NAME}-${service}-${ENVIRONMENT}" \
        --force-new-deployment \
        --region "$AWS_REGION"

    echo -e "${GREEN}Waiting for service stability...${NC}"
    aws ecs wait services-stable \
        --cluster "${PROJECT_NAME}-cluster-${ENVIRONMENT}" \
        --services "${PROJECT_NAME}-${service}-${ENVIRONMENT}" \
        --region "$AWS_REGION"

    echo -e "${GREEN}${service} deployed successfully!${NC}"
}

# Deploy based on service selection
case $SERVICE in
    backend)
        TAG=$(build_and_push "backend" "../lpr-parking-system/admin_backend")
        update_ecs_service "backend" "$TAG"
        ;;
    frontend)
        TAG=$(build_and_push "frontend" "../lpr-parking-system/admin_frontend")
        update_ecs_service "frontend" "$TAG"
        ;;
    ai-service)
        TAG=$(build_and_push "ai-service" "../SentraAI-model/service")
        update_ecs_service "ai-service" "$TAG"
        ;;
    all)
        BACKEND_TAG=$(build_and_push "backend" "../lpr-parking-system/admin_backend")
        FRONTEND_TAG=$(build_and_push "frontend" "../lpr-parking-system/admin_frontend")
        AI_TAG=$(build_and_push "ai-service" "../SentraAI-model/service")

        update_ecs_service "backend" "$BACKEND_TAG"
        update_ecs_service "frontend" "$FRONTEND_TAG"
        update_ecs_service "ai-service" "$AI_TAG"
        ;;
    *)
        echo -e "${RED}Unknown service: ${SERVICE}${NC}"
        echo "Usage: $0 <environment> <service>"
        echo "Services: backend, frontend, ai-service, all"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}=== Deployment Complete ===${NC}"
