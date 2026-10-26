variable "budget_email" {
  type        = string
  default     = ""
  description = "Operations notification address, reused from the persistent budget by the workflow."
  sensitive   = true
}

resource "aws_sns_topic_subscription" "operations_email" {
  count     = nonsensitive(var.budget_email != "") ? 1 : 0
  topic_arn = aws_sns_topic.operations.arn
  protocol  = "email"
  endpoint  = var.budget_email
}
