# Metadata only -- deliberately no aws_secretsmanager_secret_version here.
# The actual deploy-key value gets written out-of-band (aws secretsmanager
# put-secret-value) after this applies, so a private key never lands in
# Terraform state or git history in plaintext.
resource "aws_secretsmanager_secret" "gitops_deploy_key" {
  name        = "${var.project_name}-${var.environment}-${var.secret_name}"
  description = "Deploy key/PAT CodeBuild uses to push image-tag bumps to the GitOps repo. Value populated out-of-band, not by Terraform."

  tags = {
    Name = "${var.project_name}-${var.environment}-${var.secret_name}"
  }
}
