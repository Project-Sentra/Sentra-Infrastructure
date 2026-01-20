output "server_public_ip" {
  description = "Public IP of the EC2 server"
  value       = module.ec2.public_ip
}

output "server_public_dns" {
  description = "Public DNS of the EC2 server"
  value       = module.ec2.public_dns
}

output "ssh_command" {
  description = "SSH command to connect to server"
  value       = "ssh -i ${var.key_name}.pem ec2-user@${module.ec2.public_ip}"
}

output "app_url" {
  description = "Application URL"
  value       = "http://${module.ec2.public_ip}"
}

output "ecr_backend_url" {
  description = "Backend ECR repository URL"
  value       = module.ecr.backend_repository_url
}

output "ecr_frontend_url" {
  description = "Frontend ECR repository URL"
  value       = module.ecr.frontend_repository_url
}

output "ecr_ai_service_url" {
  description = "AI Service ECR repository URL"
  value       = module.ecr.ai_service_repository_url
}

output "github_actions_role_arn" {
  description = "GitHub Actions IAM role ARN"
  value       = aws_iam_role.github_actions.arn
}
