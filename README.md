# Sentra Infrastructure

Infrastructure as Code for Sentra Parking System on AWS.

## Architecture Options

### Option 1: Free Tier (Recommended for Development)
**Cost: $0-5/month**

```
         Cloudflare (DNS)
              │
              ▼
    ┌─────────────────────┐
    │   EC2 t2.micro      │
    │   (Free Tier)       │
    │                     │
    │  ┌───────────────┐  │
    │  │    Nginx      │  │ ← Reverse Proxy
    │  │   :80/:443    │  │
    │  └───────┬───────┘  │
    │          │          │
    │  ┌───────▼───────┐  │
    │  │   Docker      │  │
    │  │   Compose     │  │
    │  │               │  │
    │  │  • Frontend   │  │
    │  │  • Backend    │  │
    │  │  • AI Service │  │
    │  └───────────────┘  │
    └─────────────────────┘
              │
              ▼
         Supabase (DB)
```

### Option 2: Production (ECS Fargate)
**Cost: $70-250/month**

```
    Cloudflare → ALB → ECS Fargate (Auto-scaling)
```

---

## Quick Start (Free Tier)

### Prerequisites
- AWS Account (with free tier)
- AWS CLI configured
- Terraform >= 1.6.0
- GitHub account

### 1. Run Setup Script

```bash
cd Sentra-infrastructure/scripts
chmod +x setup-free-tier.sh
./setup-free-tier.sh
```

This will create:
- S3 bucket for Terraform state
- DynamoDB table for state locking
- EC2 key pair for SSH access
- terraform.tfvars template

### 2. Configure Supabase Credentials

Edit `terraform/environments/free-tier/terraform.tfvars`:

```hcl
supabase_url = "https://your-project.supabase.co"
supabase_key = "your-supabase-anon-key"
github_org   = "your-github-username"
```

### 3. Deploy Infrastructure

```bash
cd terraform/environments/free-tier
terraform init
terraform plan
terraform apply
```

### 4. Note the Outputs

```bash
terraform output
```

Save these values:
- `server_public_ip` - Your server IP
- `github_actions_role_arn` - For GitHub Actions
- `ssh_command` - To SSH into server

### 5. Configure GitHub Secrets

Go to your repository → Settings → Secrets → Actions

Add these secrets:

| Secret | Value |
|--------|-------|
| `AWS_ROLE_ARN` | From terraform output |
| `EC2_INSTANCE_ID` | From terraform output |
| `EC2_PUBLIC_IP` | From terraform output |

### 6. Push Code to Deploy!

```bash
git push origin main
```

GitHub Actions will:
1. Build Docker images
2. Push to ECR
3. Deploy to EC2
4. Run health checks

---

## Project Structure

```
Sentra-infrastructure/
├── terraform/
│   ├── modules/
│   │   ├── vpc/              # VPC networking
│   │   ├── ecr/              # Container registry
│   │   ├── ec2-free-tier/    # Free tier EC2
│   │   ├── ecs/              # ECS Fargate (paid)
│   │   ├── alb/              # Load balancer (paid)
│   │   └── security/         # Security groups, IAM
│   └── environments/
│       ├── free-tier/        # Free tier config
│       ├── dev/              # Development (paid)
│       └── prod/             # Production (paid)
├── scripts/
│   ├── setup-free-tier.sh    # Free tier setup
│   ├── setup-aws.sh          # Full setup
│   └── deploy.sh             # Manual deploy
└── README.md
```

---

## Free Tier Limits

| Service | Free Tier Limit | Our Usage |
|---------|----------------|-----------|
| EC2 t2.micro | 750 hrs/month | 1 instance |
| EBS | 30 GB | 20 GB |
| ECR | 500 MB | ~200-300 MB |
| Data Transfer | 1 GB outbound | Varies |
| S3 | 5 GB | < 1 MB |
| CloudWatch | 5 GB logs | < 1 GB |

**Note:** Free tier is for the first 12 months. After that, expect ~$15-20/month for t2.micro.

---

## Manual Deployment

SSH into server:
```bash
ssh -i sentra-free-key.pem ec2-user@YOUR_IP
```

Deploy:
```bash
sudo -u sentra /opt/sentra/deploy.sh
```

View logs:
```bash
sudo docker-compose -f /opt/sentra/docker-compose.yml logs -f
```

---

## Connecting Your Domain (Cloudflare)

1. Buy domain on Cloudflare ($8-10/year for .com)

2. Add DNS record:
   - Type: `A`
   - Name: `@` or `sentra`
   - Content: `YOUR_EC2_IP`
   - Proxy: `Proxied` (orange cloud)

3. SSL/TLS settings:
   - Mode: `Flexible` (free) or `Full` (with Let's Encrypt)

---

## Upgrading to Production

When ready to scale:

```bash
cd terraform/environments/dev  # or prod
cp terraform.tfvars.example terraform.tfvars
# Edit with your values
terraform init
terraform apply
```

This adds:
- Application Load Balancer
- ECS Fargate (auto-scaling)
- Multi-AZ deployment
- NAT Gateway

---

## Troubleshooting

### Can't SSH to EC2
```bash
# Check security group allows your IP
aws ec2 describe-security-groups --group-ids sg-xxx

# Update SSH allowed IPs
terraform apply -var 'ssh_allowed_cidrs=["YOUR_NEW_IP/32"]'
```

### Containers not starting
```bash
ssh -i key.pem ec2-user@IP
sudo docker-compose -f /opt/sentra/docker-compose.yml logs
```

### ECR login issues
```bash
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com
```

---

## Cost Monitoring

Set up billing alerts:
1. AWS Console → Billing → Budgets
2. Create budget: $5/month
3. Alert at 80% ($4)

---

## Security Best Practices

1. **Restrict SSH access** to your IP only
2. **Rotate credentials** periodically
3. **Enable MFA** on AWS account
4. **Don't commit** .tfvars or .pem files
5. **Use GitHub OIDC** instead of access keys

---

## License

Part of the Sentra Parking System project.
