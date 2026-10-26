resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.portfolio.id
  service_name      = "com.amazonaws.ap-northeast-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]
  tags = {
    Project   = "aws-cicd-portfolio"
    ManagedBy = "Terraform"
    Lifecycle = "persistent"
  }
}
