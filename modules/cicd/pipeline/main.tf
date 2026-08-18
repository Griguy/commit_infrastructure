data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  name_prefix = "${var.project_name}-${var.environment}-${var.service_name}"
}

# --- Artifact bucket -------------------------------------------------------
# One bucket per pipeline instantiation. A shared bucket across services
# would need prefix-scoped IAM conditions to keep one pipeline's role from
# reading another's artifacts -- not worth it for two services.
resource "aws_s3_bucket" "artifacts" {
  bucket        = "${local.name_prefix}-pipeline-artifacts-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = {
    Name = "${local.name_prefix}-pipeline-artifacts"
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# --- CodeBuild ---------------------------------------------------------------

resource "aws_iam_role" "codebuild" {
  name = "${local.name_prefix}-codebuild"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Action    = "sts:AssumeRole"
        Principal = { Service = "codebuild.amazonaws.com" }
      }
    ]
  })
}

resource "aws_iam_role_policy" "codebuild" {
  name = "${local.name_prefix}-codebuild"
  role = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Logs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = "*"
      },
      {
        Sid      = "EcrAuth"
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Sid    = "EcrPushPull"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
        ]
        Resource = var.ecr_repository_arn
      },
      {
        Sid      = "GitopsDeploySecret"
        Effect   = "Allow"
        Action   = "secretsmanager:GetSecretValue"
        Resource = var.gitops_deploy_secret_arn
      },
      {
        Sid    = "ArtifactBucket"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:GetBucketLocation",
        ]
        Resource = [
          aws_s3_bucket.artifacts.arn,
          "${aws_s3_bucket.artifacts.arn}/*",
        ]
      },
    ]
  })
}

resource "aws_codebuild_project" "this" {
  name         = local.name_prefix
  service_role = aws_iam_role.codebuild.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  # No vpc_config -- CodeBuild only needs to reach ECR, GitHub (source pull
  # happens via CodePipeline/CodeStar, not from inside the build), and
  # Secrets Manager, all of which are reachable from AWS's managed build
  # network without placing the build inside this VPC.
  environment {
    type                        = "LINUX_CONTAINER"
    image                       = var.codebuild_image
    compute_type                = var.codebuild_compute_type
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true # required for `docker build`

    environment_variable {
      name  = "ECR_REPO_URL"
      value = var.ecr_repository_url
      type  = "PLAINTEXT"
    }

    environment_variable {
      name  = "GITOPS_DEPLOY_KEY"
      value = var.gitops_deploy_secret_arn
      type  = "SECRETS_MANAGER"
    }

    environment_variable {
      name  = "GITOPS_REPO_URL"
      value = var.gitops_repo_url
      type  = "PLAINTEXT"
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec.yml"
  }

  tags = {
    Name = local.name_prefix
  }
}

# --- CodePipeline --------------------------------------------------------

resource "aws_iam_role" "codepipeline" {
  name = "${local.name_prefix}-codepipeline"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Action    = "sts:AssumeRole"
        Principal = { Service = "codepipeline.amazonaws.com" }
      }
    ]
  })
}

resource "aws_iam_role_policy" "codepipeline" {
  name = "${local.name_prefix}-codepipeline"
  role = aws_iam_role.codepipeline.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ArtifactBucket"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:GetBucketVersioning",
          "s3:GetBucketLocation",
        ]
        Resource = [
          aws_s3_bucket.artifacts.arn,
          "${aws_s3_bucket.artifacts.arn}/*",
        ]
      },
      {
        Sid      = "GithubConnection"
        Effect   = "Allow"
        Action   = "codestar-connections:UseConnection"
        Resource = var.codestar_connection_arn
      },
      {
        Sid    = "CodeBuild"
        Effect = "Allow"
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild",
        ]
        Resource = aws_codebuild_project.this.arn
      },
    ]
  })
}

resource "aws_codepipeline" "this" {
  name     = local.name_prefix
  role_arn = aws_iam_role.codepipeline.arn

  artifact_store {
    location = aws_s3_bucket.artifacts.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = var.codestar_connection_arn
        FullRepositoryId = "${var.github_owner}/${var.github_repo}"
        BranchName       = var.branch
        DetectChanges    = "true"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]

      configuration = {
        ProjectName = aws_codebuild_project.this.name
      }
    }
  }

  tags = {
    Name = local.name_prefix
  }
}
