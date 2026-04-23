variable "project_name" {
  description = "プロジェクト名"

  type = string
}

variable "vpc_cidr" {
  description = "VPCのCIDR"

  type = string

  default = "10.0.0.0/21"
}

variable "availability_zone" {
  description = "AZ"

  type = list(string)
}

variable "max_az_count" {
  description = "最大AZ数"

  type = number
}

variable "db_name" {
  description = "DB名"

  type = string
}

variable "db_user" {
  description = "DBユーザー名"

  type = string
}

variable "db_password" {
  description = "DBパスワード"

  type = string
}

variable "github_actions_allowed_subjects" {
  description = "GitHub Actions OIDC で AssumeRole を許可する sub クレーム一覧 (例: [\"repo:myorg/myrepo:ref:refs/heads/main\"])"
  type        = list(string)
}

variable "github_actions_ecr_repository_arns" {
  description = "GitHub Actions に push を許可する ECR リポジトリの ARN 一覧"
  type        = list(string)
}

variable "github_actions_ecs_passrole_arns" {
  description = "ECS タスク実行ロール・タスクロールの ARN 一覧 (iam:PassRole の対象)"
  type        = list(string)
}
