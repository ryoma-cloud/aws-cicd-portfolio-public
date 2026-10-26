resource "aws_security_group" "alb" {
  name        = "portfolio-card-alb"
  vpc_id      = data.aws_vpc.portfolio.id
  description = "Portfolio alb"

  tags = {
    Project   = "aws-cicd-portfolio"
    ManagedBy = "Terraform"
    Lifecycle = "temporary"
  }
}

resource "aws_security_group" "web" {
  name        = "portfolio-card-web"
  vpc_id      = data.aws_vpc.portfolio.id
  description = "Portfolio web"

  tags = {
    Project   = "aws-cicd-portfolio"
    ManagedBy = "Terraform"
    Lifecycle = "temporary"
  }
}

resource "aws_security_group" "registration" {
  name        = "portfolio-card-registration"
  vpc_id      = data.aws_vpc.portfolio.id
  description = "Portfolio registration"

  tags = {
    Project   = "aws-cicd-portfolio"
    ManagedBy = "Terraform"
    Lifecycle = "temporary"
  }

  depends_on = [aws_iam_role_policy_attachment.employee_register, aws_iam_role_policy_attachment.lambda_eni["employee_register"]]
}

resource "aws_security_group" "request" {
  name        = "portfolio-card-request"
  vpc_id      = data.aws_vpc.portfolio.id
  description = "Portfolio request"

  tags = {
    Project   = "aws-cicd-portfolio"
    ManagedBy = "Terraform"
    Lifecycle = "temporary"
  }

  depends_on = [aws_iam_role_policy_attachment.request_batch, aws_iam_role_policy_attachment.lambda_eni["request_batch"]]
}

resource "aws_security_group" "result" {
  name        = "portfolio-card-result"
  vpc_id      = data.aws_vpc.portfolio.id
  description = "Portfolio result"

  tags = {
    Project   = "aws-cicd-portfolio"
    ManagedBy = "Terraform"
    Lifecycle = "temporary"
  }

  depends_on = [aws_iam_role_policy_attachment.transfer_result, aws_iam_role_policy_attachment.lambda_eni["transfer_result"]]
}

resource "aws_security_group" "resend" {
  name        = "portfolio-card-resend"
  vpc_id      = data.aws_vpc.portfolio.id
  description = "Portfolio resend"

  tags = {
    Project   = "aws-cicd-portfolio"
    ManagedBy = "Terraform"
    Lifecycle = "temporary"
  }

  depends_on = [aws_iam_role_policy_attachment.resend, aws_iam_role_policy_attachment.lambda_eni["resend"]]
}

resource "aws_security_group" "migration" {
  name        = "portfolio-card-migration"
  vpc_id      = data.aws_vpc.portfolio.id
  description = "Portfolio migration"

  tags = {
    Project   = "aws-cicd-portfolio"
    ManagedBy = "Terraform"
    Lifecycle = "temporary"
  }
}

resource "aws_security_group" "endpoint" {
  name        = "portfolio-card-endpoint"
  vpc_id      = data.aws_vpc.portfolio.id
  description = "Portfolio endpoint"

  tags = {
    Project   = "aws-cicd-portfolio"
    ManagedBy = "Terraform"
    Lifecycle = "temporary"
  }
}

resource "aws_security_group" "db" {
  name        = "portfolio-card-db"
  vpc_id      = data.aws_vpc.portfolio.id
  description = "Portfolio db"

  tags = {
    Project   = "aws-cicd-portfolio"
    ManagedBy = "Terraform"
    Lifecycle = "temporary"
  }
}

resource "aws_security_group" "vendor" {
  name        = "portfolio-card-vendor"
  vpc_id      = data.aws_vpc.portfolio.id
  description = "Portfolio vendor"

  tags = {
    Project   = "aws-cicd-portfolio"
    ManagedBy = "Terraform"
    Lifecycle = "temporary"
  }
}

resource "aws_vpc_security_group_ingress_rule" "public_http" {
  security_group_id = aws_security_group.alb.id
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "web_from_alb" {
  security_group_id            = aws_security_group.web.id
  ip_protocol                  = "tcp"
  from_port                    = 8080
  to_port                      = 8080
  referenced_security_group_id = aws_security_group.alb.id
}

resource "aws_vpc_security_group_ingress_rule" "db_from_web" {
  security_group_id            = aws_security_group.db.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.web.id
}

resource "aws_vpc_security_group_ingress_rule" "db_from_registration" {
  security_group_id            = aws_security_group.db.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.registration.id
}

resource "aws_vpc_security_group_ingress_rule" "db_from_request" {
  security_group_id            = aws_security_group.db.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.request.id
}

resource "aws_vpc_security_group_ingress_rule" "db_from_result" {
  security_group_id            = aws_security_group.db.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.result.id
}

resource "aws_vpc_security_group_ingress_rule" "db_from_migration" {
  security_group_id            = aws_security_group.db.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.migration.id
}

resource "aws_vpc_security_group_ingress_rule" "endpoint_from_web" {
  security_group_id            = aws_security_group.endpoint.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.web.id
}

resource "aws_vpc_security_group_ingress_rule" "endpoint_from_registration" {
  security_group_id            = aws_security_group.endpoint.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.registration.id
}

resource "aws_vpc_security_group_ingress_rule" "endpoint_from_request" {
  security_group_id            = aws_security_group.endpoint.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.request.id
}

resource "aws_vpc_security_group_ingress_rule" "endpoint_from_result" {
  security_group_id            = aws_security_group.endpoint.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.result.id
}

resource "aws_vpc_security_group_ingress_rule" "endpoint_from_resend" {
  security_group_id            = aws_security_group.endpoint.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.resend.id
}

resource "aws_vpc_security_group_ingress_rule" "endpoint_from_migration" {
  security_group_id            = aws_security_group.endpoint.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.migration.id
}

resource "aws_vpc_security_group_egress_rule" "alb_to_web" {
  security_group_id            = aws_security_group.alb.id
  ip_protocol                  = "tcp"
  from_port                    = 8080
  to_port                      = 8080
  referenced_security_group_id = aws_security_group.web.id
}

resource "aws_vpc_security_group_egress_rule" "web_to_db" {
  security_group_id            = aws_security_group.web.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.db.id
}

resource "aws_vpc_security_group_egress_rule" "registration_to_db" {
  security_group_id            = aws_security_group.registration.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.db.id
}

resource "aws_vpc_security_group_egress_rule" "request_to_db" {
  security_group_id            = aws_security_group.request.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.db.id
}

resource "aws_vpc_security_group_egress_rule" "result_to_db" {
  security_group_id            = aws_security_group.result.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.db.id
}

resource "aws_vpc_security_group_egress_rule" "migration_to_db" {
  security_group_id            = aws_security_group.migration.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.db.id
}

resource "aws_vpc_security_group_egress_rule" "web_to_endpoint" {
  security_group_id            = aws_security_group.web.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.endpoint.id
}

resource "aws_vpc_security_group_egress_rule" "registration_to_endpoint" {
  security_group_id            = aws_security_group.registration.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.endpoint.id
}

resource "aws_vpc_security_group_egress_rule" "request_to_endpoint" {
  security_group_id            = aws_security_group.request.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.endpoint.id
}

resource "aws_vpc_security_group_egress_rule" "result_to_endpoint" {
  security_group_id            = aws_security_group.result.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.endpoint.id
}

resource "aws_vpc_security_group_egress_rule" "resend_to_endpoint" {
  security_group_id            = aws_security_group.resend.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.endpoint.id
}

resource "aws_vpc_security_group_egress_rule" "migration_to_endpoint" {
  security_group_id            = aws_security_group.migration.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.endpoint.id
}

resource "aws_vpc_security_group_egress_rule" "web_to_s3" {
  security_group_id = aws_security_group.web.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  prefix_list_id    = data.aws_vpc_endpoint.s3.prefix_list_id
}

resource "aws_vpc_security_group_egress_rule" "request_to_s3" {
  security_group_id = aws_security_group.request.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  prefix_list_id    = data.aws_vpc_endpoint.s3.prefix_list_id
}

resource "aws_vpc_security_group_egress_rule" "result_to_s3" {
  security_group_id = aws_security_group.result.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  prefix_list_id    = data.aws_vpc_endpoint.s3.prefix_list_id
}

resource "aws_vpc_security_group_egress_rule" "resend_to_s3" {
  security_group_id = aws_security_group.resend.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  prefix_list_id    = data.aws_vpc_endpoint.s3.prefix_list_id
}

resource "aws_vpc_security_group_egress_rule" "migration_to_s3" {
  security_group_id = aws_security_group.migration.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  prefix_list_id    = data.aws_vpc_endpoint.s3.prefix_list_id
}

resource "aws_vpc_security_group_egress_rule" "vendor_https" {
  security_group_id = aws_security_group.vendor.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = data.aws_vpc.portfolio.id
  service_name        = "com.amazonaws.ap-northeast-1.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = data.aws_subnets.private.ids
  security_group_ids  = [aws_security_group.endpoint.id]
  private_dns_enabled = true
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = "*"
      Action    = ["ecr:GetAuthorizationToken", "ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer", "ecr:BatchCheckLayerAvailability"]
      Resource  = "*"
      Condition = {
        ArnLike = {
          "aws:PrincipalArn" = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/portfolio-card-*"
        }
      }
    }]
  })
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = data.aws_vpc.portfolio.id
  service_name        = "com.amazonaws.ap-northeast-1.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = data.aws_subnets.private.ids
  security_group_ids  = [aws_security_group.endpoint.id]
  private_dns_enabled = true
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = "*"
      Action    = ["ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer", "ecr:BatchCheckLayerAvailability"]
      Resource  = "*"
      Condition = {
        ArnLike = {
          "aws:PrincipalArn" = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/portfolio-card-*"
        }
      }
    }]
  })
}

resource "aws_vpc_endpoint" "logs" {
  vpc_id              = data.aws_vpc.portfolio.id
  service_name        = "com.amazonaws.ap-northeast-1.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = data.aws_subnets.private.ids
  security_group_ids  = [aws_security_group.endpoint.id]
  private_dns_enabled = true
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = "*"
      Action    = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Resource  = "arn:aws:logs:ap-northeast-1:${data.aws_caller_identity.current.account_id}:log-group:*"
      Condition = {
        ArnLike = {
          "aws:PrincipalArn" = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/portfolio-card-*"
        }
      }
    }]
  })
}

resource "aws_vpc_endpoint" "secret" {
  vpc_id              = data.aws_vpc.portfolio.id
  service_name        = "com.amazonaws.ap-northeast-1.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = data.aws_subnets.private.ids
  security_group_ids  = [aws_security_group.endpoint.id]
  private_dns_enabled = true
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = "*"
      Action    = ["secretsmanager:GetSecretValue", "secretsmanager:PutSecretValue"]
      Resource = [
        aws_secretsmanager_secret.app.arn,
        aws_secretsmanager_secret.web.arn,
        aws_rds_cluster.portfolio.master_user_secret[0].secret_arn
      ]
      Condition = {
        ArnLike = {
          "aws:PrincipalArn" = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/portfolio-card-*"
        }
      }
    }]
  })
}

resource "aws_vpc_endpoint" "transfer" {
  vpc_id              = data.aws_vpc.portfolio.id
  service_name        = "com.amazonaws.ap-northeast-1.transfer"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = data.aws_subnets.private.ids
  security_group_ids  = [aws_security_group.endpoint.id]
  private_dns_enabled = true
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = "*"
      Action    = ["transfer:StartFileTransfer"]
      Resource  = "arn:aws:transfer:ap-northeast-1:${data.aws_caller_identity.current.account_id}:connector/${awscc_transfer_connector.vendor.connector_id}"
      Condition = {
        ArnLike = {
          "aws:PrincipalArn" = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/portfolio-card-*"
        }
      }
    }]
  })
}

