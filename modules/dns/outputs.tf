output "zone_id" {
  description = "Route 53 private hosted zone ID"
  value       = aws_route53_zone.private.zone_id
}

output "domain_name" {
  value = var.domain_name
}

output "fqdn" {
  description = "Full app hostname, e.g. lab-commit-task.commit-lab.internal"
  value       = local.fqdn
}

output "acm_certificate_arn" {
  description = "ARN of the imported self-signed certificate, for the ALB Ingress's ACM annotation"
  value       = aws_acm_certificate.app.arn
}
