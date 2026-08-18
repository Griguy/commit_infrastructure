# The VPC has no NAT Gateway or Internet Gateway (intentional, see module docs),
# so the SSM Agent on the instance can't reach the public SSM service endpoints.
# These PrivateLink interface endpoints give it a path without changing that
# no-internet-egress posture: RDP is then reached by tunnelling through
# `aws ssm start-session --document-name AWS-StartPortForwardingSession`, which
# needs no inbound security group rule at all since the agent forwards to
# 127.0.0.1 on the instance itself.

data "aws_region" "current" {}

resource "aws_security_group" "ssm_endpoints" {
  name        = "${var.project_name}-${var.environment}-ssm-endpoints"
  description = "Allow HTTPS from the Windows workstation to the SSM interface endpoints"
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTPS from the Windows workstation"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.windows.id]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-ssm-endpoints"
  }
}

resource "aws_vpc_endpoint" "ssm" {
  for_each = toset(["ssm", "ssmmessages", "ec2messages"])

  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.subnet_ids
  security_group_ids  = [aws_security_group.ssm_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.project_name}-${var.environment}-${each.value}"
  }
}
