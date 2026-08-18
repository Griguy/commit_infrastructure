output "secret_arn" {
  value = aws_secretsmanager_secret.gitops_deploy_key.arn
}

output "secret_name" {
  value = aws_secretsmanager_secret.gitops_deploy_key.name
}
