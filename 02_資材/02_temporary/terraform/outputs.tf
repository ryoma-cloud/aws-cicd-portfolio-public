output "employee_api_url" {
  value = "${aws_apigatewayv2_api.employees.api_endpoint}/employees"
}

output "admin_web_url" {
  value = "http://${aws_lb.admin.dns_name}"
}

output "exchange_bucket" {
  value = aws_s3_bucket.card_exchange.bucket
}

output "connector_id" {
  value = awscc_transfer_connector.vendor.connector_id
}

output "vendor_instance_id" {
  value = aws_instance.vendor.id
}

output "vendor_security_group_id" {
  value = aws_security_group.vendor.id
}

output "sftp_secret_arn" {
  value = aws_secretsmanager_secret.sftp.arn
}

output "cluster_name" {
  value = aws_ecs_cluster.portfolio.name
}

output "migration_task_definition" {
  value = aws_ecs_task_definition.migration.arn
}

output "migration_security_group" {
  value = aws_security_group.migration.id
}

output "private_subnet_ids" {
  value = data.aws_subnets.private.ids
}

output "result_function" {
  value = aws_lambda_alias.transfer_result.arn
}

output "delivery_queue_url" {
  value = aws_sqs_queue.result_delivery_dlq.id
}

output "execution_queue_url" {
  value = aws_sqs_queue.result_execution_dlq.id
}

output "registration_queue_url" {
  value = aws_sqs_queue.registration.id
}

output "batch_function" {
  value = aws_lambda_alias.request_batch.arn
}

output "resend_function" {
  value = aws_lambda_alias.resend.arn
}

output "scheduler_name" {
  value = aws_scheduler_schedule.daily.name
}

output "scheduler_group" {
  value = aws_scheduler_schedule_group.daily.name
}

output "db_cluster_identifier" {
  value = aws_rds_cluster.portfolio.cluster_identifier
}

output "vendor_eip" {
  value = aws_eip.vendor.public_ip
}

output "operations_topic" {
  value = aws_sns_topic.operations.arn
}

output "id_mock_function" {
  value = aws_lambda_alias.id_mock.arn
}

output "daily_check_scheduler_name" {
  value = aws_scheduler_schedule.daily_check.name
}

