variable "admin_image_uri" {
  type = string

  validation {
    condition     = can(regex("@sha256:[0-9a-f]{64}$", var.admin_image_uri))
    error_message = "Use an ECR image pinned by digest."
  }
}

variable "aurora_engine_version" {
  type    = string
  default = "16.15"
}

variable "sftp_host_keys" {
  type    = list(string)
  default = []
}

variable "web_desired_count" {
  type        = number
  default     = 0
  description = "Initial Web task count: 0 only for a new bootstrap; 2-4 enables request-based scaling (operational range 2-4). Existing task count is owned by Application Auto Scaling."

  validation {
    condition     = var.web_desired_count == 0 || (var.web_desired_count >= 2 && var.web_desired_count <= 4 && floor(var.web_desired_count) == var.web_desired_count)
    error_message = "Use 0 for initial bootstrap only, or an integer from 2 to 4 for initialized Web."
  }
}

variable "enable_reserved_concurrency" {
  type        = bool
  default     = true
  description = "Keep designed reserved concurrency; disable only for low-volume verification in quota-constrained accounts."
}

variable "enable_account_security" {
  type        = bool
  default     = false
  description = "Enable only after read-only ownership inventory; existing shared settings must be imported/referenced."
}

variable "enable_daily_schedule" {
  type        = bool
  default     = false
  description = "Enable both 01:00 JST batch and 03:00 JST daily completion check after readiness verification."
}
