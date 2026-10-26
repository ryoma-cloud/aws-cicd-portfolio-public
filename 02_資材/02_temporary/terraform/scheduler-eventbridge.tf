resource "aws_scheduler_schedule_group" "daily" {
  name = "portfolio-card"
}

resource "aws_scheduler_schedule" "daily" {
  depends_on = [aws_iam_role_policy_attachment.scheduler]

  name                         = "portfolio-card-daily-request"
  group_name                   = aws_scheduler_schedule_group.daily.name
  schedule_expression          = "cron(0 1 * * ? *)"
  schedule_expression_timezone = "Asia/Tokyo"
  state                        = var.enable_daily_schedule ? "ENABLED" : "DISABLED"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = aws_lambda_alias.request_batch.arn
    role_arn = aws_iam_role.scheduler.arn
    input    = jsonencode({ schema_version = 1, mode = "daily" })

    dead_letter_config {
      arn = aws_sqs_queue.schedule_delivery_dlq.arn
    }

    retry_policy {
      maximum_retry_attempts       = 2
      maximum_event_age_in_seconds = 3600
    }
  }
}

resource "aws_scheduler_schedule" "daily_check" {
  depends_on = [aws_iam_role_policy_attachment.scheduler]

  name                         = "portfolio-card-daily-check"
  group_name                   = aws_scheduler_schedule_group.daily.name
  schedule_expression          = "cron(0 3 * * ? *)"
  schedule_expression_timezone = "Asia/Tokyo"
  state                        = var.enable_daily_schedule ? "ENABLED" : "DISABLED"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = aws_lambda_alias.request_batch.arn
    role_arn = aws_iam_role.scheduler.arn
    input    = jsonencode({ schema_version = 1, mode = "check_daily" })

    dead_letter_config {
      arn = aws_sqs_queue.schedule_delivery_dlq.arn
    }

    retry_policy {
      maximum_retry_attempts       = 2
      maximum_event_age_in_seconds = 3600
    }
  }
}

resource "aws_cloudwatch_event_rule" "result" {
  name = "portfolio-card-transfer-result"
  event_pattern = jsonencode({
    source        = ["aws.transfer"]
    "detail-type" = ["SFTP Connector File Send Completed", "SFTP Connector File Send Failed"]
    detail = {
      "connector-id" = [awscc_transfer_connector.vendor.connector_id]
      operation      = ["SEND"]
    }
  })
}

resource "aws_cloudwatch_event_rule" "ecs_failure" {
  name = "portfolio-card-ecs-failure"
  event_pattern = jsonencode({
    source        = ["aws.ecs"]
    "detail-type" = ["ECS Service Action"]
    resources     = [aws_ecs_service.admin.id]
    detail = {
      eventName = [
        "SERVICE_TASK_START_IMPAIRED",
        "SERVICE_TASK_PLACEMENT_FAILURE",
        "SERVICE_TASK_CONFIGURATION_FAILURE",
        "SERVICE_DEPLOYMENT_FAILED"
      ]
    }
  })
}

resource "aws_cloudwatch_event_rule" "security_high" {
  count = var.enable_account_security ? 1 : 0
  name  = "portfolio-card-security-high"
  event_pattern = jsonencode({
    source        = ["aws.securityhub"]
    "detail-type" = ["Security Hub Findings - Imported"]
    detail = {
      findings = {
        Severity = {
          Label = ["HIGH", "CRITICAL"]
        }
        RecordState = ["ACTIVE"]
        Workflow = {
          Status = ["NEW"]
        }
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "result" {
  rule = aws_cloudwatch_event_rule.result.name
  arn  = aws_lambda_alias.transfer_result.arn

  dead_letter_config {
    arn = aws_sqs_queue.result_delivery_dlq.arn
  }

  retry_policy {
    maximum_retry_attempts       = 2
    maximum_event_age_in_seconds = 3600
  }
}

resource "aws_cloudwatch_event_target" "ecs_failure" {
  rule = aws_cloudwatch_event_rule.ecs_failure.name
  arn  = aws_sns_topic.operations.arn

  depends_on = [aws_sns_topic_policy.operations]
}

resource "aws_cloudwatch_event_target" "security_high" {
  count = var.enable_account_security ? 1 : 0
  rule  = aws_cloudwatch_event_rule.security_high[0].name
  arn   = aws_sns_topic.operations.arn
}

