output "role_arns" {
  description = "Role ARN per entry in var.roles, keyed the same way"
  value       = { for k, r in aws_iam_role.this : k => r.arn }
}
