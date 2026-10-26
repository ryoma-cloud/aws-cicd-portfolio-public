data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_vpc" "portfolio" {
  filter {
    name   = "tag:Name"
    values = ["portfolio-vpc"]
  }
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.portfolio.id]
  }

  filter {
    name   = "tag:Tier"
    values = ["public"]
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.portfolio.id]
  }

  filter {
    name   = "tag:Tier"
    values = ["private"]
  }
}

data "aws_route_tables" "private" {
  vpc_id = data.aws_vpc.portfolio.id

  filter {
    name   = "tag:Name"
    values = ["portfolio-private-rt"]
  }
}

data "aws_ssm_parameter" "ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

data "aws_vpc_endpoint" "s3" {
  vpc_id       = data.aws_vpc.portfolio.id
  service_name = "com.amazonaws.ap-northeast-1.s3"
}

locals {
  project            = "aws-cicd-portfolio"
  region             = data.aws_region.current.region
  account            = data.aws_caller_identity.current.account_id
  ecr_repository_arn = format("arn:aws:ecr:ap-northeast-1:%s:repository/%s", data.aws_caller_identity.current.account_id, split("/", split("@", var.admin_image_uri)[0])[1])
}
