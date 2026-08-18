locals {
  fqdn = "${var.app_hostname}.${var.domain_name}"
}

resource "aws_route53_zone" "private" {
  name = var.domain_name

  vpc {
    vpc_id = var.vpc_id
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-private-zone"
  }
}

# Yes, I know it stores the key material in the state. I will work around, maybe.
resource "tls_private_key" "app" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "app" {
  private_key_pem = tls_private_key.app.private_key_pem

  subject {
    common_name  = local.fqdn
    organization = var.project_name
  }

  dns_names = [local.fqdn]

  validity_period_hours = 8760 # 1 year

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "aws_acm_certificate" "app" {
  private_key      = tls_private_key.app.private_key_pem
  certificate_body = tls_self_signed_cert.app.cert_pem

  tags = {
    Name = "${var.project_name}-${var.environment}-${var.app_hostname}"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Deferred until the ALB exists: the AWS Load Balancer Controller
# provisions the internal ALB dynamically from a Kubernetes Ingress, so its
# DNS name isn't known until that's deployed. Set alb_dns_name/alb_zone_id
# once it is, and re-apply.
resource "aws_route53_record" "app" {
  count = var.alb_dns_name != null && var.alb_zone_id != null ? 1 : 0

  zone_id = aws_route53_zone.private.zone_id
  name    = local.fqdn
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}
