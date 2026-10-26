resource "aws_internet_gateway" "portfolio" {
  vpc_id = aws_vpc.portfolio.id

  tags = {
    Name        = "portfolio-igw"
    Project     = "aws-cicd-portfolio"
    ManagedBy   = "Terraform"
    Environment = "dev"
  }
}

