resource "aws_vpc" "portfolio" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "portfolio-vpc"
    Project     = "aws-cicd-portfolio"
    ManagedBy   = "Terraform"
    Environment = "dev"
  }
}

