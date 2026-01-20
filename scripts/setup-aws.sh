#!/bin/bash
# Setup script for AWS infrastructure prerequisites

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Sentra AWS Infrastructure Setup ===${NC}"

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo -e "${RED}AWS CLI not found. Please install it first.${NC}"
    exit 1
fi

# Check Terraform
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}Terraform not found. Please install it first.${NC}"
    exit 1
fi

# Configuration
PROJECT_NAME="sentra"
AWS_REGION="${AWS_REGION:-us-east-1}"
ENVIRONMENT="${1:-dev}"

echo -e "${YELLOW}Project: ${PROJECT_NAME}${NC}"
echo -e "${YELLOW}Region: ${AWS_REGION}${NC}"
echo -e "${YELLOW}Environment: ${ENVIRONMENT}${NC}"
echo ""

# Create S3 bucket for Terraform state
BUCKET_NAME="${PROJECT_NAME}-terraform-state-${ENVIRONMENT}"
echo -e "${GREEN}Creating S3 bucket for Terraform state: ${BUCKET_NAME}${NC}"

if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    echo "Bucket already exists"
else
    aws s3api create-bucket \
        --bucket "$BUCKET_NAME" \
        --region "$AWS_REGION" \
        ${AWS_REGION:+--create-bucket-configuration LocationConstraint=$AWS_REGION} 2>/dev/null || \
    aws s3api create-bucket \
        --bucket "$BUCKET_NAME" \
        --region "$AWS_REGION"

    # Enable versioning
    aws s3api put-bucket-versioning \
        --bucket "$BUCKET_NAME" \
        --versioning-configuration Status=Enabled

    # Enable encryption
    aws s3api put-bucket-encryption \
        --bucket "$BUCKET_NAME" \
        --server-side-encryption-configuration '{
            "Rules": [
                {
                    "ApplyServerSideEncryptionByDefault": {
                        "SSEAlgorithm": "AES256"
                    }
                }
            ]
        }'

    echo -e "${GREEN}S3 bucket created successfully${NC}"
fi

# Create DynamoDB table for state locking
TABLE_NAME="${PROJECT_NAME}-terraform-locks"
echo -e "${GREEN}Creating DynamoDB table for state locking: ${TABLE_NAME}${NC}"

if aws dynamodb describe-table --table-name "$TABLE_NAME" --region "$AWS_REGION" 2>/dev/null; then
    echo "DynamoDB table already exists"
else
    aws dynamodb create-table \
        --table-name "$TABLE_NAME" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region "$AWS_REGION"

    echo -e "${GREEN}DynamoDB table created successfully${NC}"
fi

# Create EC2 key pair
KEY_NAME="${PROJECT_NAME}-${ENVIRONMENT}-key"
echo -e "${GREEN}Creating EC2 key pair: ${KEY_NAME}${NC}"

if aws ec2 describe-key-pairs --key-names "$KEY_NAME" --region "$AWS_REGION" 2>/dev/null; then
    echo "Key pair already exists"
else
    aws ec2 create-key-pair \
        --key-name "$KEY_NAME" \
        --query 'KeyMaterial' \
        --output text \
        --region "$AWS_REGION" > "${KEY_NAME}.pem"

    chmod 400 "${KEY_NAME}.pem"
    echo -e "${GREEN}Key pair created and saved to ${KEY_NAME}.pem${NC}"
    echo -e "${YELLOW}IMPORTANT: Keep this file safe and never commit it to git!${NC}"
fi

echo ""
echo -e "${GREEN}=== Setup Complete ===${NC}"
echo ""
echo "Next steps:"
echo "1. cd terraform/environments/${ENVIRONMENT}"
echo "2. cp terraform.tfvars.example terraform.tfvars"
echo "3. Edit terraform.tfvars with your values"
echo "4. terraform init"
echo "5. terraform plan"
echo "6. terraform apply"
