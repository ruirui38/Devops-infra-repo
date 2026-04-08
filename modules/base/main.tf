#VPC
resource "aws_vpc" "vpc" {
  cidr_block = var.vpc_cidr

  enable_dns_hostnames = true

  enable_dns_support = true

  tags =  {
    Name = "${var.project_name}-vpc"
  }
}

#Public subnt
resource "aws_subnet" "public" {
  count = length(var.availability_zone)

  vpc_id = aws_vpc.vpc.id

  cidr_block = cidrsubnet(var.vpc_cidr,3,count.index)

  availability_zone = var.availability_zone[count.index]

  tags = {
    Name = "${var.project_name}-public-subnet-${substr(var.availability_zone[count.index], -2, 2)}"
  }
}