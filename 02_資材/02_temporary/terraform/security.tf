resource "aws_guardduty_detector" "portfolio" {
  count                        = var.enable_account_security ? 1 : 0
  enable                       = true
  finding_publishing_frequency = "FIFTEEN_MINUTES"
}

resource "aws_inspector2_enabler" "portfolio" {
  count          = var.enable_account_security ? 1 : 0
  account_ids    = [data.aws_caller_identity.current.account_id]
  resource_types = ["ECR", "LAMBDA"]
}

resource "aws_ecr_registry_scanning_configuration" "portfolio" {
  count     = var.enable_account_security ? 1 : 0
  scan_type = "ENHANCED"

  rule {
    scan_frequency = "CONTINUOUS_SCAN"

    repository_filter {
      filter      = "portfolio-admin-web"
      filter_type = "WILDCARD"
    }
  }

  depends_on = [aws_inspector2_enabler.portfolio]
}

resource "aws_securityhub_account" "portfolio" {
  count                    = var.enable_account_security ? 1 : 0
  enable_default_standards = false
  auto_enable_controls     = false
}

resource "aws_securityhub_standards_subscription" "portfolio" {
  count         = var.enable_account_security ? 1 : 0
  standards_arn = "arn:aws:securityhub:ap-northeast-1::standards/aws-foundational-security-best-practices/v/1.0.0"

  # AWS側の標準初期化が既定3分を超える場合があるため、完了を最大15分待つ。
  timeouts {
    create = "15m"
  }

  depends_on = [
    aws_securityhub_account.portfolio,
    aws_config_configuration_recorder_status.portfolio
  ]
}

resource "aws_config_configuration_recorder" "portfolio" {
  count    = var.enable_account_security ? 1 : 0
  name     = "portfolio-card"
  role_arn = aws_iam_role.config[0].arn

  recording_group {
    all_supported                 = false
    include_global_resource_types = false
    resource_types = [
      "AWS::S3::Bucket",
      "AWS::EC2::SecurityGroup",
      "AWS::RDS::DBInstance",
      "AWS::RDS::DBCluster"
    ]
  }

  recording_mode {
    recording_frequency = "CONTINUOUS"
  }
}

resource "aws_config_delivery_channel" "portfolio" {
  count          = var.enable_account_security ? 1 : 0
  name           = "portfolio-card"
  s3_bucket_name = "portfolio-card-config-${data.aws_caller_identity.current.account_id}-ap-northeast-1"

  depends_on = [
    aws_config_configuration_recorder.portfolio,
    aws_iam_role_policy_attachment.config_delivery,
    aws_iam_role_policy_attachment.config
  ]
}

resource "aws_config_configuration_recorder_status" "portfolio" {
  count      = var.enable_account_security ? 1 : 0
  name       = aws_config_configuration_recorder.portfolio[0].name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.portfolio]
}

