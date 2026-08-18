output "windows_instance_id" {
  description = "Target ID for `aws ssm start-session --document-name AWS-StartPortForwardingSession`"
  value       = aws_instance.windows.id
}

output "windows_private_ip" {
  value = aws_instance.windows.private_ip
}

output "windows_admin_password" {
  value     = random_password.windows_admin.result
  sensitive = true
}
