#ECR
resource "aws_ecr_repository" "api" {
  name = "${var.project_name}-api"

  image_tag_mutability = "MUTABLE"

  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.project_name}-api"
  }
}

#ECRライフサイクルポリシー (5世代管理)
resource "aws_ecr_lifecycle_policy" "count_policy" {
  repository = aws_ecr_repository.api.name

  policy = <<EOF
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Keep last 5 images",
      "selection": {
        "tagStatus": "any",
        "countType": "imageCountMoreThan",
        "countNumber": 5
      },
      "action": {
        "type": "expire"
      }
    }
  ]
}
EOF
}
