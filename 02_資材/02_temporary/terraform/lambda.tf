resource "aws_lambda_function" "employee_intake" {
  function_name    = "portfolio-card-employee-intake"
  role             = aws_iam_role.employee_intake.arn
  runtime          = "python3.13"
  handler          = "app.lambda_handler"
  filename         = "${path.module}/build/employee_intake.zip"
  source_code_hash = filebase64sha256("${path.module}/build/employee_intake.zip")
  memory_size      = 128
  timeout          = 25
  publish          = true

  environment {
    variables = {
      TZ                     = "Asia/Tokyo"
      LOG_LEVEL              = "INFO"
      SYSTEM_NAME            = "portfolio-card"
      REGISTRATION_QUEUE_URL = aws_sqs_queue.registration.id
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.employee_intake,
    aws_cloudwatch_log_group.employee_intake
  ]

  tags = {
    Project   = "aws-cicd-portfolio"
    ManagedBy = "Terraform"
    Lifecycle = "temporary"
  }
}

resource "aws_lambda_function" "employee_register" {
  function_name    = "portfolio-card-employee-register"
  role             = aws_iam_role.employee_register.arn
  runtime          = "python3.13"
  handler          = "app.lambda_handler"
  filename         = "${path.module}/build/employee_register.zip"
  source_code_hash = filebase64sha256("${path.module}/build/employee_register.zip")
  memory_size      = 256
  timeout          = 30
  publish          = true

  environment {
    variables = {
      TZ             = "Asia/Tokyo"
      LOG_LEVEL      = "INFO"
      SYSTEM_NAME    = "portfolio-card"
      DB_SECRET_ARN  = aws_secretsmanager_secret.app.arn
      DB_HOST        = aws_rds_cluster.portfolio.endpoint
      DB_NAME        = "portfolio"
      DB_SSLROOTCERT = "/var/task/certs/global-bundle.pem"
    }
  }

  reserved_concurrent_executions = var.enable_reserved_concurrency ? 5 : -1

  vpc_config {
    subnet_ids         = data.aws_subnets.private.ids
    security_group_ids = [aws_security_group.registration.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.employee_register,
    aws_iam_role_policy_attachment.lambda_eni["employee_register"],
    aws_cloudwatch_log_group.employee_register
  ]

  tags = {
    Project   = "aws-cicd-portfolio"
    ManagedBy = "Terraform"
    Lifecycle = "temporary"
  }
}

resource "aws_lambda_function" "request_batch" {
  function_name    = "portfolio-card-request-batch"
  role             = aws_iam_role.request_batch.arn
  runtime          = "python3.13"
  handler          = "app.lambda_handler"
  filename         = "${path.module}/build/request_batch.zip"
  source_code_hash = filebase64sha256("${path.module}/build/request_batch.zip")
  memory_size      = 512
  timeout          = 300
  publish          = true

  environment {
    variables = {
      TZ                  = "Asia/Tokyo"
      LOG_LEVEL           = "INFO"
      SYSTEM_NAME         = "portfolio-card"
      DB_SECRET_ARN       = aws_secretsmanager_secret.app.arn
      DB_HOST             = aws_rds_cluster.portfolio.endpoint
      DB_NAME             = "portfolio"
      DB_SSLROOTCERT      = "/var/task/certs/global-bundle.pem"
      EXCHANGE_BUCKET     = aws_s3_bucket.card_exchange.bucket
      CONNECTOR_ID        = awscc_transfer_connector.vendor.connector_id
      REMOTE_DIRECTORY    = "/inbox"
      EXPECTED_ACCOUNT_ID = data.aws_caller_identity.current.account_id
    }
  }

  reserved_concurrent_executions = var.enable_reserved_concurrency ? 1 : -1

  vpc_config {
    subnet_ids         = data.aws_subnets.private.ids
    security_group_ids = [aws_security_group.request.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.request_batch,
    aws_iam_role_policy_attachment.lambda_eni["request_batch"],
    aws_cloudwatch_log_group.request_batch
  ]

  tags = {
    Project   = "aws-cicd-portfolio"
    ManagedBy = "Terraform"
    Lifecycle = "temporary"
  }
}

resource "aws_lambda_function" "transfer_result" {
  function_name    = "portfolio-card-transfer-result"
  role             = aws_iam_role.transfer_result.arn
  runtime          = "python3.13"
  handler          = "app.lambda_handler"
  filename         = "${path.module}/build/transfer_result.zip"
  source_code_hash = filebase64sha256("${path.module}/build/transfer_result.zip")
  memory_size      = 256
  timeout          = 60
  publish          = true

  environment {
    variables = {
      TZ                  = "Asia/Tokyo"
      LOG_LEVEL           = "INFO"
      SYSTEM_NAME         = "portfolio-card"
      DB_SECRET_ARN       = aws_secretsmanager_secret.app.arn
      DB_HOST             = aws_rds_cluster.portfolio.endpoint
      DB_NAME             = "portfolio"
      DB_SSLROOTCERT      = "/var/task/certs/global-bundle.pem"
      EXCHANGE_BUCKET     = aws_s3_bucket.card_exchange.bucket
      CONNECTOR_ID        = awscc_transfer_connector.vendor.connector_id
      REMOTE_DIRECTORY    = "/inbox"
      EXPECTED_ACCOUNT_ID = data.aws_caller_identity.current.account_id
    }
  }

  reserved_concurrent_executions = var.enable_reserved_concurrency ? 5 : -1

  vpc_config {
    subnet_ids         = data.aws_subnets.private.ids
    security_group_ids = [aws_security_group.result.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.transfer_result,
    aws_iam_role_policy_attachment.lambda_eni["transfer_result"],
    aws_cloudwatch_log_group.transfer_result
  ]

  tags = {
    Project   = "aws-cicd-portfolio"
    ManagedBy = "Terraform"
    Lifecycle = "temporary"
  }
}

resource "aws_lambda_function" "resend" {
  function_name    = "portfolio-card-resend"
  role             = aws_iam_role.resend.arn
  runtime          = "python3.13"
  handler          = "app.lambda_handler"
  filename         = "${path.module}/build/resend.zip"
  source_code_hash = filebase64sha256("${path.module}/build/resend.zip")
  memory_size      = 256
  timeout          = 300
  publish          = true

  environment {
    variables = {
      TZ                  = "Asia/Tokyo"
      LOG_LEVEL           = "INFO"
      SYSTEM_NAME         = "portfolio-card"
      EXCHANGE_BUCKET     = aws_s3_bucket.card_exchange.bucket
      CONNECTOR_ID        = awscc_transfer_connector.vendor.connector_id
      REMOTE_DIRECTORY    = "/inbox"
      EXPECTED_ACCOUNT_ID = data.aws_caller_identity.current.account_id
    }
  }

  reserved_concurrent_executions = var.enable_reserved_concurrency ? 1 : -1

  vpc_config {
    subnet_ids         = data.aws_subnets.private.ids
    security_group_ids = [aws_security_group.resend.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.resend,
    aws_iam_role_policy_attachment.lambda_eni["resend"],
    aws_cloudwatch_log_group.resend
  ]

  tags = {
    Project   = "aws-cicd-portfolio"
    ManagedBy = "Terraform"
    Lifecycle = "temporary"
  }
}

resource "aws_lambda_function" "id_mock" {
  function_name    = "portfolio-id-system-mock"
  role             = aws_iam_role.id_mock.arn
  runtime          = "python3.13"
  handler          = "app.lambda_handler"
  filename         = "${path.module}/build/id_mock.zip"
  source_code_hash = filebase64sha256("${path.module}/build/id_mock.zip")
  memory_size      = 128
  timeout          = 60
  publish          = true

  environment {
    variables = {
      API_ENDPOINT = "${aws_apigatewayv2_api.employees.api_endpoint}/employees"
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.id_mock,
    aws_cloudwatch_log_group.id_mock
  ]
}

resource "aws_lambda_alias" "employee_intake" {
  name             = "live"
  function_name    = aws_lambda_function.employee_intake.function_name
  function_version = aws_lambda_function.employee_intake.version
}

resource "aws_lambda_alias" "employee_register" {
  name             = "live"
  function_name    = aws_lambda_function.employee_register.function_name
  function_version = aws_lambda_function.employee_register.version
}

resource "aws_lambda_alias" "request_batch" {
  name             = "live"
  function_name    = aws_lambda_function.request_batch.function_name
  function_version = aws_lambda_function.request_batch.version
}

resource "aws_lambda_alias" "transfer_result" {
  name             = "live"
  function_name    = aws_lambda_function.transfer_result.function_name
  function_version = aws_lambda_function.transfer_result.version
}

resource "aws_lambda_alias" "resend" {
  name             = "live"
  function_name    = aws_lambda_function.resend.function_name
  function_version = aws_lambda_function.resend.version
}

resource "aws_lambda_alias" "id_mock" {
  name             = "live"
  function_name    = aws_lambda_function.id_mock.function_name
  function_version = aws_lambda_function.id_mock.version
}

resource "aws_lambda_event_source_mapping" "registration" {
  event_source_arn        = aws_sqs_queue.registration.arn
  function_name           = aws_lambda_alias.employee_register.arn
  batch_size              = 1
  function_response_types = ["ReportBatchItemFailures"]

  scaling_config {
    maximum_concurrency = 5
  }
}

resource "aws_lambda_function_event_invoke_config" "transfer_result" {
  function_name                = aws_lambda_function.transfer_result.function_name
  qualifier                    = aws_lambda_alias.transfer_result.name
  maximum_retry_attempts       = 2
  maximum_event_age_in_seconds = 3600

  destination_config {
    on_failure {
      destination = aws_sqs_queue.result_execution_dlq.arn
    }
  }
}

resource "aws_lambda_function_event_invoke_config" "request_batch" {
  function_name                = aws_lambda_function.request_batch.function_name
  qualifier                    = aws_lambda_alias.request_batch.name
  maximum_retry_attempts       = 0
  maximum_event_age_in_seconds = 3600
}

resource "aws_lambda_permission" "api" {
  statement_id  = "ApiInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.employee_intake.function_name
  qualifier     = "live"
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.employees.execution_arn}/*/POST/employees"
}

resource "aws_lambda_permission" "result" {
  statement_id  = "EventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.transfer_result.function_name
  qualifier     = "live"
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.result.arn
}

