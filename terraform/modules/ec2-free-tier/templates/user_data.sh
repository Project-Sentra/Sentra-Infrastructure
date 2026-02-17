#!/bin/bash
set -e

# Log output
exec > >(tee /var/log/user-data.log) 2>&1

echo "=== Sentra Server Setup (Free Tier) ==="
echo "Environment: ${environment}"
echo "Region: ${aws_region}"

# Update system
dnf update -y

# Install Docker
dnf install -y docker git
systemctl enable docker
systemctl start docker

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Create app user and add to docker group
useradd -m -s /bin/bash sentra || true
usermod -aG docker sentra

# Create directories
mkdir -p /opt/sentra/{config,data,logs}
chown -R sentra:sentra /opt/sentra

# Create environment file
cat > /opt/sentra/.env << 'ENVFILE'
SUPABASE_URL=${supabase_url}
SUPABASE_KEY=${supabase_key}
ENVIRONMENT=${environment}
AWS_REGION=${aws_region}
ECR_REGISTRY=${ecr_registry}
ENVFILE

chown sentra:sentra /opt/sentra/.env
chmod 600 /opt/sentra/.env

# Create docker-compose.yml
cat > /opt/sentra/docker-compose.yml << 'COMPOSEFILE'
version: '3.8'

services:
  nginx:
    image: nginx:alpine
    container_name: sentra-nginx
    ports:
      - "80:80"
    volumes:
      - ./config/nginx.conf:/etc/nginx/conf.d/default.conf:ro
    depends_on:
      - frontend
      - backend
    restart: unless-stopped
    networks:
      - sentra-network

  frontend:
    image: $${ECR_REGISTRY}/sentra-frontend:latest
    container_name: sentra-frontend
    restart: unless-stopped
    networks:
      - sentra-network

  backend:
    image: $${ECR_REGISTRY}/sentra-backend:latest
    container_name: sentra-backend
    environment:
      - SUPABASE_URL=$${SUPABASE_URL}
      - SUPABASE_KEY=$${SUPABASE_KEY}
      - ENVIRONMENT=$${ENVIRONMENT}
    restart: unless-stopped
    networks:
      - sentra-network

  ai-service:
    image: $${ECR_REGISTRY}/sentra-ai-service:latest
    container_name: sentra-ai-service
    environment:
      - PARKING_API_URL=http://backend:5000
      - ENVIRONMENT=$${ENVIRONMENT}
      - MIN_CONFIDENCE=0.5
      - AUTO_ENTRY_EXIT=false
      - CAMERA_MODE=live
    restart: unless-stopped
    networks:
      - sentra-network

networks:
  sentra-network:
    driver: bridge
COMPOSEFILE

chown sentra:sentra /opt/sentra/docker-compose.yml

# Create Nginx config (uses runtime DNS resolution so missing services don't block startup)
mkdir -p /opt/sentra/config
cat > /opt/sentra/config/nginx.conf << 'NGINXCONF'
resolver 127.0.0.11 valid=30s ipv6=off;

server {
    listen 80;
    server_name _;

    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml;

    location / {
        set $frontend_upstream http://sentra-frontend:80;
        proxy_pass $frontend_upstream;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /api/ {
        set $backend_upstream http://sentra-backend:5000;
        proxy_pass $backend_upstream;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /ai/ {
        set $ai_upstream http://sentra-ai-service:5001;
        rewrite ^/ai/(.*) /api/$1 break;
        proxy_pass $ai_upstream;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location /ws {
        set $ws_upstream http://sentra-ai-service:5001;
        rewrite ^/ws /api/ws break;
        proxy_pass $ws_upstream;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_read_timeout 86400;
    }

    location /health {
        access_log off;
        return 200 "healthy";
        add_header Content-Type text/plain;
    }
}
NGINXCONF

chown -R sentra:sentra /opt/sentra/config

# Create deployment script
cat > /opt/sentra/deploy.sh << 'DEPLOYSCRIPT'
#!/bin/bash
set -e

cd /opt/sentra
source .env

# Login to ECR
aws ecr get-login-password --region $${AWS_REGION} | docker login --username AWS --password-stdin $${ECR_REGISTRY}

# Pull latest images
docker-compose pull

# Restart services
docker-compose up -d

# Cleanup old images
docker image prune -f

echo "Deployment complete!"
DEPLOYSCRIPT

chmod +x /opt/sentra/deploy.sh
chown sentra:sentra /opt/sentra/deploy.sh

# Create systemd service for auto-start
cat > /etc/systemd/system/sentra.service << 'SERVICEFILE'
[Unit]
Description=Sentra Parking System
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
User=sentra
WorkingDirectory=/opt/sentra
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down

[Install]
WantedBy=multi-user.target
SERVICEFILE

systemctl daemon-reload
systemctl enable sentra

echo "=== Setup Complete ==="
echo "Run /opt/sentra/deploy.sh to deploy the application"
