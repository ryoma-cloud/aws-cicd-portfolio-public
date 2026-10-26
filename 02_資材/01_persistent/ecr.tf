resource "aws_ecr_repository" "admin_web" {
  name                 = "portfolio-admin-web"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Project   = "aws-cicd-portfolio"
    ManagedBy = "Terraform"
    Purpose   = "admin-web"
  }
}

resource "aws_ecr_lifecycle_policy" "admin_web" {
  repository = aws_ecr_repository.admin_web.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep the latest 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}

