resource "aws_secretsmanager_secret" "app" {
  name                    = "portfolio/card/db-app"
  recovery_window_in_days = 0

  tags = {
    Project   = "aws-cicd-portfolio"
    ManagedBy = "Terraform"
    Lifecycle = "temporary"
  }
}

resource "aws_secretsmanager_secret" "web" {
  name                    = "portfolio/card/db-web"
  recovery_window_in_days = 0

  tags = {
    Project   = "aws-cicd-portfolio"
    ManagedBy = "Terraform"
    Lifecycle = "temporary"
  }
}

resource "aws_secretsmanager_secret" "sftp" {
  name                    = "portfolio/mock/card-vendor/sftp"
  recovery_window_in_days = 0

  tags = {
    Project   = "aws-cicd-portfolio"
    ManagedBy = "Terraform"
    Lifecycle = "temporary"
  }
}
