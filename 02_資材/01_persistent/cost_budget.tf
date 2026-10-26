variable "budget_email" {
  description = "AWS Budgetsの通知先メールアドレス"
  type        = string
  sensitive   = true
}

resource "aws_budgets_budget" "monthly_cost" {
  name         = "portfolio-monthly-cost"
  budget_type  = "COST"
  limit_amount = "30"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_types {
    include_credit  = false
    include_refund  = false
    include_tax     = true
    include_support = true
  }

  dynamic "notification" {
    for_each = [10, 20, 30, 40]

    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = notification.value
      threshold_type             = "ABSOLUTE_VALUE"
      notification_type          = "ACTUAL"
      subscriber_email_addresses = [var.budget_email]
    }
  }
}

