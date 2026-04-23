#VPC
resource "aws_vpc" "vpc" {
  cidr_block = var.vpc_cidr

  enable_dns_hostnames = true

  enable_dns_support = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

#Public subnt
resource "aws_subnet" "public" {
  count = length(var.availability_zone)

  vpc_id = aws_vpc.vpc.id

  cidr_block = cidrsubnet(var.vpc_cidr, 3, count.index)

  availability_zone = var.availability_zone[count.index]

  tags = {
    Name = "${var.project_name}-public-subnet-${substr(var.availability_zone[count.index], -2, 2)}"
  }
}

#Protected subnet
resource "aws_subnet" "protected" {
  count = length(var.availability_zone)

  vpc_id = aws_vpc.vpc.id

  cidr_block = cidrsubnet(var.vpc_cidr, 3, count.index + length(var.availability_zone))

  availability_zone = var.availability_zone[count.index]

  tags = {
    Name = "${var.project_name}-protected-subnet-${substr(var.availability_zone[count.index], -2, 2)}"
  }
}

# Private subnet
resource "aws_subnet" "private" {
  count = length(var.availability_zone)

  vpc_id = aws_vpc.vpc.id

  cidr_block = cidrsubnet(var.vpc_cidr, 3, count.index + var.max_az_count * 2)

  availability_zone = var.availability_zone[count.index]

  tags = {
    Name = "${var.project_name}-private-subnet-${substr(var.availability_zone[count.index], -2, 2)}"
  }
}

#Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

#リージョナルNAT
resource "aws_nat_gateway" "nat" {
  vpc_id            = aws_vpc.vpc.id
  availability_mode = "regional"

  tags = {
    Name = "${var.project_name}-nat-gw"
  }
}

#Route Table
resource "aws_route_table" "public_rtb" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name  = "${var.project_name}-public-rtb"
  }
}

resource "aws_route_table" "protected_rtb" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id  = aws_nat_gateway.nat.id
  }
  
  tags = {
    Name  = "${var.project_name}-protected-rtb"
  }
}

resource "aws_route_table" "private_rtb" {
  vpc_id = aws_vpc.vpc.id
  
  tags = {
    Name  = "${var.project_name}-private-rtb"
  }
}

#Route table Assosiation
resource "aws_route_table_association" "public" {
  count = length(var.availability_zone)

  subnet_id = aws_subnet.public[count.index].id

  route_table_id = aws_route_table.public_rtb.id
}

resource "aws_route_table_association" "protected" {
  count = length(var.availability_zone)

  subnet_id = aws_subnet.protected[count.index].id

  route_table_id = aws_route_table.protected_rtb.id
}

resource "aws_route_table_association" "private" {
  count = length(var.availability_zone)

  subnet_id = aws_subnet.private[count.index].id

  route_table_id = aws_route_table.private_rtb.id
}

#ALB用SG
resource "aws_security_group" "alb" {
  name = "${var.project_name}-alb-sg"

  description = "security group for alb"

  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port = 80

    to_port = 80

    protocol = "tcp"

    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port = 8080

    to_port = 8080

    protocol = "tcp"

    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0

    to_port = 0

    protocol = "-1"

    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

#ECS用SG  (API)
resource "aws_security_group" "api" {
  name = "${var.project_name}-api-sg"

  description = "security group for api"

  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port = 8000

    to_port = 8000

    protocol = "tcp"

    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port = 0

    to_port = 0

    protocol = "-1"

    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-api-sg"
  }
}

 #Security Group
resource "aws_security_group" "db" {
  name   = "${var.project_name}-db-sg"
  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.api.id] 
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-db-sg"
  }
}

# Subnet Group
resource "aws_db_subnet_group" "db" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

# Cluster Parameter Group
resource "aws_rds_cluster_parameter_group" "db" {
  name   = "${var.project_name}-cluster-pg"
  family = "aurora-mysql8.0"

  parameter {
    name  = "time_zone"
    value = "Asia/Tokyo"
  }

  tags = {
    Name = "${var.project_name}-cluster-pg"
  }
}

# DB Parameter Group
resource "aws_db_parameter_group" "db" {
  name   = "${var.project_name}-db-pg"
  family = "aurora-mysql8.0"

  tags = {
    Name = "${var.project_name}-db-pg"
  }
}

#RDS
resource "aws_rds_cluster" "rds_cluster" {
  cluster_identifier = "${var.project_name}-db-cluster"

  engine = "aurora-mysql"

  engine_version = "8.0.mysql_aurora.3.04.0"

  database_name = var.db_name

  master_username = var.db_user

  master_password = var.db_password

  db_subnet_group_name = aws_db_subnet_group.db.name

  vpc_security_group_ids = [aws_security_group.db.id]

  skip_final_snapshot = true

  backup_retention_period = 5

  preferred_backup_window = "05:00-07:00"

  storage_encrypted = true

  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.db.name

  tags = {
    Name = "${var.project_name}-db-cluster"
  }
}

resource "aws_rds_cluster_instance" "db_instance" {
  count                   = 1
  identifier              = "${var.project_name}-aurora-instance-${count.index}"
  cluster_identifier      = aws_rds_cluster.rds_cluster.id
  instance_class          = "db.t3.medium"
  engine                  = aws_rds_cluster.rds_cluster.engine
  engine_version          = aws_rds_cluster.rds_cluster.engine_version
  db_parameter_group_name = aws_db_parameter_group.db.name

  tags = {
    Name = "${var.project_name}-aurora-instance-${count.index}"
  }
}

# CloudWatch Logsグループ
resource "aws_cloudwatch_log_group" "api" {
  name              = "/ecs/${var.project_name}-api"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-api-logs"
  }
}

#S3 (ALBアクセスログ用)
resource "aws_s3_bucket" "alb_logs" {
  bucket = "${var.project_name}-alb-logs"

  tags = {
    Name = "${var.project_name}-alb-logs"
  }
}

# バケットポリシー
resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::582318560864:root"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.alb_logs.arn}/*"
      }
    ]
  })
}

#S3ゲートウェイエンドポイント
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.vpc.id
  service_name = "com.amazonaws.ap-northeast-1.s3"

  route_table_ids = [aws_route_table.protected_rtb.id]

    tags = {
    Name = "${var.project_name}-vpce-s3"
  }
}

# GitHub Actions OIDC Provider
resource "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  # GitHub OIDC thumbprint
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1b511abead59c6ce207077c0bf0e0043b1382612",
  ]

  tags = {
    Name = "${var.project_name}-github-actions-oidc-provider"
  }
}

# 信頼ポリシー: 指定リポジトリ・ブランチのみ AssumeRole を許可
data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      # 例: ["repo:myorg/myrepo:ref:refs/heads/main"]
      values = var.github_actions_allowed_subjects
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "${var.project_name}-github-actions-role"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json

  tags = {
    Name = "${var.project_name}-github-actions-role"
  }
}

# ECR イメージプッシュ権限
data "aws_iam_policy_document" "github_actions_ecr" {
  statement {
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
    ]
    resources = var.github_actions_ecr_repository_arns
  }
}

resource "aws_iam_policy" "github_actions_ecr" {
  name   = "${var.project_name}-github-actions-ecr-policy"
  policy = data.aws_iam_policy_document.github_actions_ecr.json

  tags = {
    Name = "${var.project_name}-github-actions-ecr-policy"
  }
}

resource "aws_iam_role_policy_attachment" "github_actions_ecr" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions_ecr.arn
}

# ECS デプロイ権限（タスク定義更新・サービス更新）
data "aws_iam_policy_document" "github_actions_ecs" {
  statement {
    effect = "Allow"
    actions = [
      "ecs:RegisterTaskDefinition",
      "ecs:DescribeTaskDefinition",
      "ecs:UpdateService",
      "ecs:DescribeServices",
    ]
    resources = ["*"]
  }

  # ECS がタスク実行ロール・タスクロールを引き受けるための PassRole
  statement {
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = var.github_actions_ecs_passrole_arns
  }
}

resource "aws_iam_policy" "github_actions_ecs" {
  name   = "${var.project_name}-github-actions-ecs-policy"
  policy = data.aws_iam_policy_document.github_actions_ecs.json

  tags = {
    Name = "${var.project_name}-github-actions-ecs-policy"
  }
}

resource "aws_iam_role_policy_attachment" "github_actions_ecs" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions_ecs.arn
}