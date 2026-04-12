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

#Private subnet
resource "aws_subnet" "private" {
  count = length(var.availability_zone)

  vpc_id = aws_vpc.vpc.id

  cidr_block = cidrsubnet(var.vpc_cidr, 3, count.index + length(var.availability_zone))

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

#Route Table
resource "aws_route_table" "publuc_rtb" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

#Route table Assosiation
resource "aws_route_table_association" "public" {
  count = length(var.availability_zone)

  subnet_id = aws_subnet.public[count.index].id

  route_table_id = aws_route_table.publuc_rtb.id
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

# # CloudWatch Logsグループ
# resource "aws_cloudwatch_log_group" "api" {
#   name              = "/ecs/${var.project_name}-api"
#   retention_in_days = 7

#   tags = {
#     Name = "${var.project_name}-api-logs"
#   }
# }
