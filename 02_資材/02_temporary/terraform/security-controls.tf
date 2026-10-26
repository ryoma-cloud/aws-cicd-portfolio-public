locals {
  security_standard         = "arn:aws:securityhub:ap-northeast-1::standards/aws-foundational-security-best-practices/v/1.0.0"
  enabled_security_controls = toset(["S3.2", "S3.3", "S3.5", "S3.8", "RDS.2", "RDS.3", "RDS.27", "EC2.19"])
  guardduty_optional_features = toset([
    "S3_DATA_EVENTS", "EKS_AUDIT_LOGS", "EBS_MALWARE_PROTECTION",
    "RDS_LOGIN_EVENTS", "LAMBDA_NETWORK_LOGS", "RUNTIME_MONITORING",
    "AI_PROTECTION", "AI_ANALYST"
  ])
}

# Read the catalogue during plan; do not depend on a newly-created subscription.
data "aws_securityhub_security_controls" "portfolio" {
  count         = var.enable_account_security ? 1 : 0
  standards_arn = local.security_standard
}

resource "aws_securityhub_standards_control_association" "portfolio" {
  for_each = var.enable_account_security ? {
    for control in data.aws_securityhub_security_controls.portfolio[0].security_control_definitions :
    control.security_control_id => control
    if control.current_region_availability == "AVAILABLE"
  } : {}
  standards_arn       = local.security_standard
  security_control_id = each.key
  association_status  = contains(local.enabled_security_controls, each.key) ? "ENABLED" : "DISABLED"
  updated_reason      = contains(local.enabled_security_controls, each.key) ? null : "Outside the agreed small portfolio assessment scope"
  depends_on          = [aws_securityhub_standards_subscription.portfolio]
}

resource "aws_guardduty_detector_feature" "optional" {
  for_each    = var.enable_account_security ? setsubtract(local.guardduty_optional_features, toset(["RDS_LOGIN_EVENTS"])) : toset([])
  detector_id = aws_guardduty_detector.portfolio[0].id
  name        = each.key
  status      = "DISABLED"

  dynamic "additional_configuration" {
    for_each = each.key == "RUNTIME_MONITORING" ? toset([
      "EC2_AGENT_MANAGEMENT", "ECS_FARGATE_AGENT_MANAGEMENT", "EKS_ADDON_MANAGEMENT"
    ]) : toset([])
    content {
      name   = additional_configuration.value
      status = "DISABLED"
    }
  }
}

# AWS returns RDS_DATA_RISK, but aws 6.67.0 cannot configure this child value.
# The parent is disabled; only this unsupported child configuration is ignored.
resource "aws_guardduty_detector_feature" "rds" {
  count       = var.enable_account_security ? 1 : 0
  detector_id = aws_guardduty_detector.portfolio[0].id
  name        = "RDS_LOGIN_EVENTS"
  status      = "DISABLED"
  lifecycle {
    ignore_changes = [additional_configuration]
  }
}

moved {
  from = aws_guardduty_detector_feature.optional["RDS_LOGIN_EVENTS"]
  to   = aws_guardduty_detector_feature.rds[0]
}
