locals {
  persistent_log_groups = {
    admin_web             = "/ecs/portfolio-card-admin"
    core_api              = "/aws/lambda/portfolio-card-core-api"
    vendor_result_import  = "/aws/lambda/portfolio-card-result-import"
    id_system_simulator   = "/aws/lambda/portfolio-id-system-sim"
    card_vendor_simulator = "/aws/lambda/portfolio-card-vendor-sim"
  }
}

resource "aws_cloudwatch_log_group" "persistent" {
  for_each = local.persistent_log_groups

  name              = each.value
  retention_in_days = 90

  tags = {
    Project   = "aws-cicd-portfolio"
    ManagedBy = "Terraform"
    Lifecycle = "persistent"
  }
}

