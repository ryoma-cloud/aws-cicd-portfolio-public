resource "aws_apigatewayv2_api" "employees" {
  name          = "portfolio-card-employee"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "employees" {
  api_id                 = aws_apigatewayv2_api.employees.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_alias.employee_intake.invoke_arn
  payload_format_version = "2.0"
  timeout_milliseconds   = 30000
}

resource "aws_apigatewayv2_route" "employees" {
  api_id             = aws_apigatewayv2_api.employees.id
  route_key          = "POST /employees"
  authorization_type = "AWS_IAM"
  target             = "integrations/${aws_apigatewayv2_integration.employees.id}"
}

resource "aws_apigatewayv2_stage" "employees" {
  api_id      = aws_apigatewayv2_api.employees.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_rate_limit  = 5
    throttling_burst_limit = 10
  }

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api.arn
    format          = "{\"requestId\": \"$context.requestId\", \"status\": \"$context.status\", \"routeKey\": \"$context.routeKey\"}"
  }
}
