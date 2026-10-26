output "portfolio_vpc_id" {
  description = "VPC ID for temporary stacks"
  value       = aws_vpc.portfolio.id
}

output "portfolio_public_subnet_ids" {
  description = "Public subnet IDs keyed by AZ suffix"
  value       = { for az, subnet in aws_subnet.public : az => subnet.id }
}

output "portfolio_private_subnet_ids" {
  description = "Future-use private subnet IDs keyed by AZ suffix"
  value       = { for az, subnet in aws_subnet.private : az => subnet.id }
}

output "admin_web_ecr_repository_url" {
  description = "Persistent ECR repository used by the temporary admin web service"
  value       = aws_ecr_repository.admin_web.repository_url
}

output "persistent_log_group_names" {
  description = "CloudWatch log groups intentionally retained when 02_temporary is destroyed"
  value       = values(local.persistent_log_groups)
}

