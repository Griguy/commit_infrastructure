# One IAM role per entry in var.roles, trusted only by the specific
# Kubernetes ServiceAccount named in that entry -- the `sub` condition scopes
# the trust to `system:serviceaccount:<namespace>:<service_account_name>`,
# so no other ServiceAccount in the cluster can assume it, even though they
# all share the same OIDC provider.
resource "aws_iam_role" "this" {
  for_each = var.roles

  name = "${var.project_name}-${var.environment}-${each.key}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Federated = var.oidc_provider_arn }
        Action    = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${var.oidc_provider_url}:aud" = "sts.amazonaws.com"
            "${var.oidc_provider_url}:sub" = "system:serviceaccount:${each.value.namespace}:${each.value.service_account_name}"
          }
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-${each.key}"
  }
}

locals {
  role_policy_pairs = merge([
    for role_key, role in var.roles : {
      for policy_arn in role.policy_arns :
      "${role_key}|${policy_arn}" => {
        role_key   = role_key
        policy_arn = policy_arn
      }
    }
  ]...)
}

resource "aws_iam_role_policy_attachment" "this" {
  for_each = local.role_policy_pairs

  role       = aws_iam_role.this[each.value.role_key].name
  policy_arn = each.value.policy_arn
}
