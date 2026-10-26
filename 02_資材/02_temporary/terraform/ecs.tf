resource "aws_ecs_cluster" "portfolio" {
  name = "portfolio-card"

  tags = {
    Project   = "aws-cicd-portfolio"
    ManagedBy = "Terraform"
    Lifecycle = "temporary"
  }
}

resource "aws_ecs_task_definition" "web" {
  depends_on = [aws_iam_role_policy_attachment.ecs_execution, aws_iam_role_policy_attachment.web_task]

  family                   = "portfolio-card-web"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.web_task.arn

  container_definitions = jsonencode([{
    name                   = "web"
    image                  = var.admin_image_uri
    essential              = true
    readonlyRootFilesystem = true
    user                   = "65532:65532"
    environment = [
      { name = "DB_NAME", value = "portfolio" },
      { name = "DB_HOST", value = aws_rds_cluster.portfolio.reader_endpoint },
      { name = "DB_SECRET_ARN", value = aws_secretsmanager_secret.web.arn },
      { name = "APP_SECRET_ARN", value = aws_secretsmanager_secret.app.arn },
      { name = "WEB_SECRET_ARN", value = aws_secretsmanager_secret.web.arn }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.web.name
        "awslogs-region"        = "ap-northeast-1"
        "awslogs-stream-prefix" = "web"
      }
    }
    portMappings = [{
      containerPort = 8080
      protocol      = "tcp"
    }]
    command = [
      "gunicorn",
      "--bind=0.0.0.0:8080",
      "--workers=1",
      "--threads=2",
      "--worker-tmp-dir=/dev/shm",
      "--error-logfile=-",
      "web.app:app"
    ]
    stopTimeout = 30
    healthCheck = {
      command = [
        "CMD",
        "python",
        "-c",
        "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/health', timeout=3).close()"
      ]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 30
    }
  }])
}

resource "aws_ecs_task_definition" "migration" {
  depends_on = [aws_iam_role_policy_attachment.ecs_execution, aws_iam_role_policy_attachment.migration_task]

  family                   = "portfolio-card-migration"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.migration_task.arn

  container_definitions = jsonencode([{
    name                   = "migration"
    image                  = var.admin_image_uri
    essential              = true
    readonlyRootFilesystem = true
    user                   = "65532:65532"
    environment = [
      { name = "DB_NAME", value = "portfolio" },
      { name = "DB_HOST", value = aws_rds_cluster.portfolio.endpoint },
      { name = "DB_SECRET_ARN", value = aws_rds_cluster.portfolio.master_user_secret[0].secret_arn },
      { name = "APP_SECRET_ARN", value = aws_secretsmanager_secret.app.arn },
      { name = "WEB_SECRET_ARN", value = aws_secretsmanager_secret.web.arn }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.web.name
        "awslogs-region"        = "ap-northeast-1"
        "awslogs-stream-prefix" = "migration"
      }
    }
    command = ["python", "tools/migrate.py"]
  }])
}

resource "aws_ecs_service" "admin" {
  name                               = "portfolio-card-web"
  cluster                            = aws_ecs_cluster.portfolio.id
  task_definition                    = aws_ecs_task_definition.web.arn
  desired_count                      = var.web_desired_count
  launch_type                        = "FARGATE"
  health_check_grace_period_seconds  = 60
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = data.aws_subnets.private.ids
    security_groups  = [aws_security_group.web.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.admin.arn
    container_name   = "web"
    container_port   = 8080
  }

  depends_on = [
    aws_lb_listener.admin,
    aws_vpc_endpoint.ecr_api,
    aws_vpc_endpoint.ecr_dkr,
    aws_vpc_endpoint.logs
  ]

  lifecycle {
    ignore_changes = [desired_count]
  }
}
