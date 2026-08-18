output "db_endpoint" {
  description = "Connection endpoint, host:port"
  value       = aws_db_instance.this.endpoint
}

output "db_address" {
  description = "Host name, without the port"
  value       = aws_db_instance.this.address
}

output "db_port" {
  value = aws_db_instance.this.port
}

output "db_name" {
  value = aws_db_instance.this.db_name
}

output "db_username" {
  value = aws_db_instance.this.username
}

output "db_password" {
  value     = random_password.master.result
  sensitive = true
}

output "rds_security_group_id" {
  description = "Security group attached to the RDS instance itself"
  value       = aws_security_group.rds.id
}
