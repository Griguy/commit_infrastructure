# Comes up in PENDING status -- AWS requires a human to click through the
# GitHub OAuth authorization in the console once per connection, there's no
# API for it. CodePipeline's Source stage can't actually pull from GitHub
# until that one-time authorization happens.
resource "aws_codestarconnections_connection" "github" {
  name          = "${var.project_name}-${var.environment}-${var.connection_name}"
  provider_type = "GitHub"
}
