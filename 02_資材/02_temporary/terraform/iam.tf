resource "aws_iam_role" "transfer" {
  name = "portfolio-card-transfer"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "transfer.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role" "vendor" {
  name = "portfolio-card-vendor"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role" "employee_intake" {
  name = "portfolio-card-employee_intake"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role" "employee_register" {
  name = "portfolio-card-employee_register"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role" "request_batch" {
  name = "portfolio-card-request_batch"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role" "transfer_result" {
  name = "portfolio-card-transfer_result"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role" "resend" {
  name = "portfolio-card-resend"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role" "scheduler" {
  name = "portfolio-card-scheduler"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "scheduler.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role" "ecs_execution" {
  name = "portfolio-card-ecs_execution"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role" "web_task" {
  name = "portfolio-card-web_task"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role" "migration_task" {
  name = "portfolio-card-migration_task"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role" "id_mock" {
  name = "portfolio-card-id-mock"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role" "config" {
  count = var.enable_account_security ? 1 : 0
  name  = "portfolio-card-config"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "config.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role" "transfer_logging" {
  name = "portfolio-card-transfer-logs"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "transfer.amazonaws.com"
      }
      Action = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
        ArnLike = {
          "aws:SourceArn" = "arn:aws:transfer:ap-northeast-1:${data.aws_caller_identity.current.account_id}:connector/*"
        }
      }
    }]
  })

  tags = {
    Project   = "aws-cicd-portfolio"
    ManagedBy = "Terraform"
    Lifecycle = "temporary"
  }
}

resource "aws_iam_policy" "transfer" {
  name = "portfolio-card-transfer-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:GetObjectVersion", "s3:PutObject"]
        Resource = [
          "${aws_s3_bucket.card_exchange.arn}/transfer/*",
          "${aws_s3_bucket.card_exchange.arn}/failed/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetBucketLocation"]
        Resource = aws_s3_bucket.card_exchange.arn
      },
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = aws_secretsmanager_secret.sftp.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "transfer" {
  role       = aws_iam_role.transfer.name
  policy_arn = aws_iam_policy.transfer.arn
}

resource "aws_iam_policy" "employee_intake" {
  name = "portfolio-card-employee-intake-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = [
          "arn:aws:logs:ap-northeast-1:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/portfolio-card-*:*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["sqs:SendMessage"]
        Resource = aws_sqs_queue.registration.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "employee_intake" {
  role       = aws_iam_role.employee_intake.name
  policy_arn = aws_iam_policy.employee_intake.arn
}

resource "aws_iam_policy" "employee_register" {
  name = "portfolio-card-employee-register-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = [
          "arn:aws:logs:ap-northeast-1:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/portfolio-card-*:*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["ec2:DescribeSubnets"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = aws_secretsmanager_secret.app.arn
      },
      {
        Effect   = "Allow"
        Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
        Resource = aws_sqs_queue.registration.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "employee_register" {
  role       = aws_iam_role.employee_register.name
  policy_arn = aws_iam_policy.employee_register.arn
}

resource "aws_iam_policy" "request_batch" {
  name = "portfolio-card-request-batch-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = [
          "arn:aws:logs:ap-northeast-1:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/portfolio-card-*:*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["ec2:DescribeSubnets"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = aws_secretsmanager_secret.app.arn
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = aws_s3_bucket.card_exchange.arn
      },
      {
        Effect   = "Allow"
        Action   = ["transfer:StartFileTransfer"]
        Resource = "arn:aws:transfer:ap-northeast-1:${data.aws_caller_identity.current.account_id}:connector/${awscc_transfer_connector.vendor.connector_id}"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = "${aws_s3_bucket.card_exchange.arn}/transfer/*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:GetObject"]
        Resource = "${aws_s3_bucket.card_exchange.arn}/daily/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "request_batch" {
  role       = aws_iam_role.request_batch.name
  policy_arn = aws_iam_policy.request_batch.arn
}

resource "aws_iam_policy" "transfer_result" {
  name = "portfolio-card-transfer-result-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = [
          "arn:aws:logs:ap-northeast-1:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/portfolio-card-*:*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["ec2:DescribeSubnets"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = aws_secretsmanager_secret.app.arn
      },
      {
        Effect = "Allow"
        Action = ["s3:GetObject"]
        Resource = [
          "${aws_s3_bucket.card_exchange.arn}/transfer/*",
          "${aws_s3_bucket.card_exchange.arn}/failed/*",
          "${aws_s3_bucket.card_exchange.arn}/success/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = aws_s3_bucket.card_exchange.arn
      },
      {
        Effect = "Allow"
        Action = ["s3:PutObject", "s3:DeleteObject"]
        Resource = [
          "${aws_s3_bucket.card_exchange.arn}/transfer/*",
          "${aws_s3_bucket.card_exchange.arn}/failed/*",
          "${aws_s3_bucket.card_exchange.arn}/success/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["sqs:SendMessage"]
        Resource = aws_sqs_queue.result_execution_dlq.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "transfer_result" {
  role       = aws_iam_role.transfer_result.name
  policy_arn = aws_iam_policy.transfer_result.arn
}

resource "aws_iam_policy" "resend" {
  name = "portfolio-card-resend-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = [
          "arn:aws:logs:ap-northeast-1:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/portfolio-card-*:*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["ec2:DescribeSubnets"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = aws_s3_bucket.card_exchange.arn
      },
      {
        Effect   = "Allow"
        Action   = ["transfer:StartFileTransfer"]
        Resource = "arn:aws:transfer:ap-northeast-1:${data.aws_caller_identity.current.account_id}:connector/${awscc_transfer_connector.vendor.connector_id}"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "resend" {
  role       = aws_iam_role.resend.name
  policy_arn = aws_iam_policy.resend.arn
}

resource "aws_iam_policy" "scheduler" {
  name = "portfolio-card-scheduler-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["lambda:InvokeFunction"]
        Resource = aws_lambda_alias.request_batch.arn
      },
      {
        Effect   = "Allow"
        Action   = ["sqs:SendMessage"]
        Resource = aws_sqs_queue.schedule_delivery_dlq.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "scheduler" {
  role       = aws_iam_role.scheduler.name
  policy_arn = aws_iam_policy.scheduler.arn
}

resource "aws_iam_policy" "ecs_execution" {
  name = "portfolio-card-ecs-execution-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer", "ecr:BatchCheckLayerAvailability"]
        Resource = local.ecr_repository_arn
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "${aws_cloudwatch_log_group.web.arn}:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = aws_iam_policy.ecs_execution.arn
}

resource "aws_iam_policy" "web_task" {
  name = "portfolio-card-web-task-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = aws_secretsmanager_secret.web.arn
    }]
  })
}

resource "aws_iam_role_policy_attachment" "web_task" {
  role       = aws_iam_role.web_task.name
  policy_arn = aws_iam_policy.web_task.arn
}

resource "aws_iam_policy" "migration_task" {
  name = "portfolio-card-migration-task-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue"]
        Resource = [
          aws_rds_cluster.portfolio.master_user_secret[0].secret_arn,
          aws_secretsmanager_secret.app.arn,
          aws_secretsmanager_secret.web.arn
        ]
      },
      {
        Effect = "Allow"
        Action = ["secretsmanager:PutSecretValue"]
        Resource = [
          aws_secretsmanager_secret.app.arn,
          aws_secretsmanager_secret.web.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "migration_task" {
  role       = aws_iam_role.migration_task.name
  policy_arn = aws_iam_policy.migration_task.arn
}

resource "aws_iam_policy" "id_mock" {
  name = "portfolio-card-id-mock-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "execute-api:Invoke"
        Resource = "${aws_apigatewayv2_api.employees.execution_arn}/*/POST/employees"
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "${aws_cloudwatch_log_group.id_mock.arn}:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "id_mock" {
  role       = aws_iam_role.id_mock.name
  policy_arn = aws_iam_policy.id_mock.arn
}

resource "aws_iam_policy" "config_delivery" {
  name = "portfolio-card-config-delivery-policy"

  count = var.enable_account_security ? 1 : 0
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetBucketAcl", "s3:ListBucket"]
        Resource = "arn:aws:s3:::portfolio-card-config-${data.aws_caller_identity.current.account_id}-ap-northeast-1"
      },
      {
        Effect   = "Allow"
        Action   = "s3:PutObject"
        Resource = "arn:aws:s3:::portfolio-card-config-${data.aws_caller_identity.current.account_id}-ap-northeast-1/AWSLogs/${data.aws_caller_identity.current.account_id}/Config/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "config_delivery" {
  count      = var.enable_account_security ? 1 : 0
  role       = aws_iam_role.config[0].name
  policy_arn = aws_iam_policy.config_delivery[count.index].arn
}

resource "aws_iam_policy" "transfer_logging" {
  name = "portfolio-card-transfer-logging-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["logs:CreateLogStream", "logs:DescribeLogStreams", "logs:PutLogEvents"]
      Resource = [
        aws_cloudwatch_log_group.transfer_connector.arn,
        "${aws_cloudwatch_log_group.transfer_connector.arn}:*"
      ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "transfer_logging" {
  role       = aws_iam_role.transfer_logging.name
  policy_arn = aws_iam_policy.transfer_logging.arn
}

# VPC Lambda ENI operations use the AWS managed policy; scoped application access stays separate.
resource "aws_iam_role_policy_attachment" "lambda_eni" {
  for_each = {
    employee_register = aws_iam_role.employee_register.name
    request_batch     = aws_iam_role.request_batch.name
    transfer_result   = aws_iam_role.transfer_result.name
    resend            = aws_iam_role.resend.name
  }
  role       = each.value
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaENIManagementAccess"
}

resource "aws_iam_role_policy_attachment" "vendor_ssm" {
  role       = aws_iam_role.vendor.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "config" {
  count      = var.enable_account_security ? 1 : 0
  role       = aws_iam_role.config[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_iam_instance_profile" "vendor" {
  name = "portfolio-card-vendor"
  role = aws_iam_role.vendor.name
}

