# IMMUTABLE tags match the CI pipeline's git-SHA tagging strategy -- every
# build produces a new tag, so nothing ever needs to overwrite an existing
# one, and immutability guards against a compromised or buggy build silently
# replacing an image that's already been deployed.
resource "aws_ecr_repository" "this" {
  for_each = toset(var.repository_names)

  name                 = each.value
  image_tag_mutability = "IMMUTABLE"
  # Without this, `terraform destroy` refuses to remove a repository that
  # still holds images (RepositoryNotEmptyException) -- hit exactly that
  # doing a full environment teardown/recreate, since CI had already pushed
  # real images by then. Lab environment, not a registry anything else
  # depends on, so losing the images on destroy is the expected trade-off.
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = each.value
  }
}

# Untagged images pile up from every build that pushes a new tagged image
# without cleaning up the previous manifest's dangling layers; expire them
# after a few days instead of paying to store them indefinitely.
resource "aws_ecr_lifecycle_policy" "this" {
  for_each = aws_ecr_repository.this

  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = var.untagged_image_expiry_days
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
