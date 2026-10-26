locals {
  public_subnets = {
    a = { cidr = "10.20.1.0/24", az = "ap-northeast-1a" }
    c = { cidr = "10.20.2.0/24", az = "ap-northeast-1c" }
  }
  private_subnets = {
    a = { cidr = "10.20.11.0/24", az = "ap-northeast-1a" }
    c = { cidr = "10.20.12.0/24", az = "ap-northeast-1c" }
  }
}

resource "aws_subnet" "public" {
  for_each                = local.public_subnets
  vpc_id                  = aws_vpc.portfolio.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = false

  tags = {
    Name        = "portfolio-public-${each.key}"
    Project     = "aws-cicd-portfolio"
    ManagedBy   = "Terraform"
    Environment = "dev"
    Tier        = "public"
  }
}

resource "aws_subnet" "private" {
  for_each                = local.private_subnets
  vpc_id                  = aws_vpc.portfolio.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = false

  tags = {
    Name        = "portfolio-private-${each.key}"
    Project     = "aws-cicd-portfolio"
    ManagedBy   = "Terraform"
    Environment = "dev"
    Tier        = "private"
  }
}

