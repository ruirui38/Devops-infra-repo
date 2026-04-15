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

#ECS用SG  (API)
resource "aws_security_group" "api" {
  name = "${var.project_name}-api-sg"

  description = "security group for api"

  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port = 80

    to_port = 80

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
  count                   = 2
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
