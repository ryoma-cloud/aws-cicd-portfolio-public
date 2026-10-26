variable "existing_connector_id" {
  type        = string
  default     = ""
  description = "Existing connector ID supplied by the read-only state preflight for provider adoption."
}

variable "existing_sftp_rule_import_id" {
  type        = string
  default     = ""
  description = "Validated legacy security group rule import ID; empty for a fresh environment."
}

# Transfer management without deleting the existing AWS connector.
removed {
  from = aws_transfer_connector.vendor
  lifecycle {
    destroy = false
  }
}

import {
  for_each = var.existing_connector_id != "" ? { vendor = var.existing_connector_id } : {}
  to       = awscc_transfer_connector.vendor
  id       = each.value
}

import {
  for_each = var.existing_sftp_rule_import_id != "" ? { vendor = var.existing_sftp_rule_import_id } : {}
  to       = aws_security_group_rule.vendor_sftp
  id       = each.value
}
