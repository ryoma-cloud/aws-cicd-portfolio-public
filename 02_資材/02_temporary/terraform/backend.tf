terraform {
  backend "s3" {
    key          = "aws-cicd-portfolio/temporary/terraform.tfstate"
    region       = "ap-northeast-1"
    encrypt      = true
    use_lockfile = true
  }
}


