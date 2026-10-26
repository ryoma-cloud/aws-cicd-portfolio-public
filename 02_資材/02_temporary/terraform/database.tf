resource "aws_db_subnet_group" "portfolio" {
  name       = "portfolio-card-db-subnets"
  subnet_ids = data.aws_subnets.private.ids
}

resource "aws_rds_cluster_parameter_group" "portfolio" {
  name   = "portfolio-card-pg16"
  family = "aurora-postgresql16"

  parameter {
    name  = "timezone"
    value = "Asia/Tokyo"
  }

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  parameter {
    name  = "log_statement"
    value = "none"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "-1"
  }

  parameter {
    name  = "log_parameter_max_length"
    value = "0"
  }

  parameter {
    name  = "log_parameter_max_length_on_error"
    value = "0"
  }

  parameter {
    name  = "log_min_error_statement"
    value = "panic"
  }
}

resource "aws_rds_cluster" "portfolio" {
  cluster_identifier              = "portfolio-card-db"
  engine                          = "aurora-postgresql"
  engine_mode                     = "provisioned"
  engine_version                  = var.aurora_engine_version
  database_name                   = "portfolio"
  master_username                 = "portfolio_admin"
  manage_master_user_password     = true
  enable_http_endpoint            = false
  db_subnet_group_name            = aws_db_subnet_group.portfolio.name
  vpc_security_group_ids          = [aws_security_group.db.id]
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.portfolio.name
  storage_encrypted               = true
  backup_retention_period         = 7
  preferred_backup_window         = "18:00-18:30"
  preferred_maintenance_window    = "sat:18:30-sat:19:00"
  skip_final_snapshot             = true
  deletion_protection             = false
  copy_tags_to_snapshot           = true
  enabled_cloudwatch_logs_exports = ["postgresql"]

  tags = {
    Project   = "aws-cicd-portfolio"
    ManagedBy = "Terraform"
    Lifecycle = "temporary"
  }

  depends_on = [aws_cloudwatch_log_group.rds_postgresql]
}

resource "aws_rds_cluster_instance" "instance1" {
  identifier          = "portfolio-card-db-1"
  cluster_identifier  = aws_rds_cluster.portfolio.id
  instance_class      = "db.t4g.medium"
  engine              = "aurora-postgresql"
  publicly_accessible = false
  promotion_tier      = 1
  availability_zone   = "ap-northeast-1a"

  preferred_maintenance_window = "sat:19:00-sat:19:30"

  tags = {
    Project   = "aws-cicd-portfolio"
    ManagedBy = "Terraform"
    Lifecycle = "temporary"
  }
}

resource "aws_rds_cluster_instance" "instance2" {
  identifier          = "portfolio-card-db-2"
  cluster_identifier  = aws_rds_cluster.portfolio.id
  instance_class      = "db.t4g.medium"
  engine              = "aurora-postgresql"
  publicly_accessible = false
  promotion_tier      = 0
  availability_zone   = "ap-northeast-1c"

  preferred_maintenance_window = "sat:20:00-sat:20:30"

  tags = {
    Project   = "aws-cicd-portfolio"
    ManagedBy = "Terraform"
    Lifecycle = "temporary"
  }
}
