# DB migration runs with web_desired_count=0. Register only after it completes.
# ECS desired_count is ignored in ecs.tf so apply preserves scaled capacity.
# Steady-state range: 2-4 tasks; rolling deployments may temporarily exceed 4.
resource "aws_appautoscaling_target" "web" {
  count              = var.web_desired_count > 0 ? 1 : 0
  min_capacity       = 2
  max_capacity       = 4
  resource_id        = "service/${aws_ecs_cluster.portfolio.name}/${aws_ecs_service.admin.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "web_requests" {
  count              = var.web_desired_count > 0 ? 1 : 0
  name               = "portfolio-card-web-requests"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.web[0].resource_id
  scalable_dimension = aws_appautoscaling_target.web[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.web[0].service_namespace

  target_tracking_scaling_policy_configuration {
    # Requests per target per minute (not the total ALB request count).
    # This low target demonstrates scaling; it is not a throughput limit.
    target_value       = 10
    scale_out_cooldown = 60
    scale_in_cooldown  = 300
    disable_scale_in   = false
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = "${aws_lb.admin.arn_suffix}/${aws_lb_target_group.admin.arn_suffix}"
    }
  }
}

