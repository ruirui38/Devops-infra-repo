#Target Group
resource "aws_lb_target_group" "front_end_blue" {
  name        = "${var.project_name}-blue-tg"
  port        = 8000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
  }
}

resource "aws_lb_target_group" "front_end_green" {
  name        = "${var.project_name}-green-tg"
  port        = 8000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
  }
}

#S3 (ALBログ用)
resource "aws_s3_bucket" "log_bucket" {
  bucket = "${var.project_name}-alb-logs-bucket"
}

#ALB
resource "aws_alb" "alb" {
  name = "${var.project_name}-alb"

  internal = false

  load_balancer_type = "application"

  security_groups = [var.alb_security_group_id]

  subnets = var.public_subnet_ids

  access_logs {
    bucket  = var.alb_logs
    prefix  = "alb-logs"
    enabled = true
  }

  tags = {
    Name = "${var.project_name}-alb"
  }
}

resource "aws_alb_listener" "front_end" {
  load_balancer_arn = aws_alb.alb.id

  port = "80"

  protocol = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Fixed response content"
      status_code  = "404"
    }
  }
}

resource "aws_alb_listener_rule" "rule1" {
  listener_arn = aws_alb_listener.front_end.arn

  priority = 1

  action {
    type = "forward"

    forward {
      target_group {
        arn    = aws_lb_target_group.front_end_blue.arn
        weight = 100
      }
      target_group {
        arn    = aws_lb_target_group.front_end_green.arn
        weight = 0
      }
    }
  }

  condition {
    host_header {
      values = [
        aws_alb.alb.dns_name
      ]
    }
  }
}

resource "aws_alb_listener" "test" {
  load_balancer_arn = aws_alb.alb.id

  port = "8080"

  protocol = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Fixed response content"
      status_code  = "404"
    }
  }
}

resource "aws_alb_listener_rule" "test_rule" {
  listener_arn = aws_alb_listener.test.arn

  priority = 1

  action {
    type = "forward"

    forward {
      target_group {
        arn    = aws_lb_target_group.front_end_blue.arn
        weight = 100
      }
      target_group {
        arn    = aws_lb_target_group.front_end_green.arn
        weight = 0
      }
    }
  }

  condition {
    host_header {
      values = [
        aws_alb.alb.dns_name
      ]
    }
  }
}

# ECSタスク実行ロール
resource "aws_iam_role" "task_exec_role" {
  name = "${var.project_name}-task-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# AWS管理ポリシーのみアタッチ
resource "aws_iam_role_policy_attachment" "task_exec_managed_policy" {
  role       = aws_iam_role.task_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

#ECS Blue/Green用ロール
resource "aws_iam_role" "ecs_infrastructure_role_for_load_balancers" {
  name = "${var.project_name}-ecs-infrastructure-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# ALB操作に必要なポリシーをアタッチ
resource "aws_iam_role_policy_attachment" "ecs_infrastructure_role_for_load_balancers" {
  role       = aws_iam_role.ecs_infrastructure_role_for_load_balancers.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonECSInfrastructureRolePolicyForLoadBalancers"
}

#ECS
resource "aws_ecs_cluster" "cluster" {
  name = "${var.project_name}-cluster"

  tags = {
    Name = "${var.project_name}-cluster"
  }
}

resource "aws_ecs_task_definition" "api_tasldef" {
  family = "${var.project_name}-api"

  requires_compatibilities = ["FARGATE"]

  network_mode = "awsvpc"

  cpu    = "256"
  memory = "512"

  execution_role_arn = aws_iam_role.task_exec_role.arn

  container_definitions = jsonencode([
    {
      name      = "api"
      image     = "${var.ecr_repository_url}:${var.container_image_tag}"
      cpu       = 10
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = 8000
          hostPort      = 8000
        }
      ],
      environment = [
        { name = "DB_HOST", value = var.db_host },
        { name = "DB_NAME", value = var.db_name },
        { name = "DB_USER", value = var.db_user },
        { name = "DB_PASSWORD", value = var.db_password },
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.cloudwatch_log_group_name
          "awslogs-region"        = "ap-northeast-1"
          "awslogs-stream-prefix" = "api"
        }
      }
    }
  ])

  tags = {
    Name = "${var.project_name}-taskdef"
  }
}

#ECSサービス
resource "aws_ecs_service" "service" {
  name = "${var.project_name}-service"

  launch_type = "FARGATE"

  cluster = aws_ecs_cluster.cluster.id

  task_definition = aws_ecs_task_definition.api_tasldef.arn

  desired_count = 1

  deployment_configuration {
    strategy             = "BLUE_GREEN"
    bake_time_in_minutes = "1"
  }
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  wait_for_steady_state = true

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.api_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.front_end_blue.arn
    container_name   = "api"
    container_port   = 8000
    advanced_configuration {
      alternate_target_group_arn = aws_lb_target_group.front_end_green.arn
      production_listener_rule   = aws_alb_listener_rule.rule1.arn
      role_arn                   = aws_iam_role.ecs_infrastructure_role_for_load_balancers.arn
      test_listener_rule         = aws_alb_listener_rule.test_rule.arn
    }
  }
}
