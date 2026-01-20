output "alb_security_group_id" {
  value = aws_security_group.alb.id
}

output "ecs_security_group_id" {
  value = aws_security_group.ecs.id
}

output "supabase_url_secret_arn" {
  value = aws_secretsmanager_secret.supabase_url.arn
}

output "supabase_key_secret_arn" {
  value = aws_secretsmanager_secret.supabase_key.arn
}

output "github_actions_role_arn" {
  value = var.create_github_oidc ? aws_iam_role.github_actions[0].arn : null
}
