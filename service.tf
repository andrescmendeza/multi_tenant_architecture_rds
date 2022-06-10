# -----------------------------------------
# DNS Record
# -----------------------------------------

resource "aws_route53_record" "app_record" {
  zone_id = data.aws_route53_zone.app.zone_id
  name    = "${terraform.workspace}-tms-api.${var.domain}"
  type    = "A"

  alias {
    name                   = aws_alb.load_balancer.dns_name
    zone_id                = aws_alb.load_balancer.zone_id
    evaluate_target_health = true
  }

  depends_on = [aws_alb.load_balancer]
}


# -----------------------------------------
# ALB Target Groups
# -----------------------------------------
# Create the target groups for the
# blue/green deployments

resource "aws_alb_target_group" "tg-A" {
  name        = "${terraform.workspace}-tg-A"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.vpc.id
  target_type = "ip"

  health_check {
    healthy_threshold   = "3"
    interval            = "30"
    protocol            = "HTTP"
    matcher             = "200"
    timeout             = "3"
    path                = var.health_check_path
    unhealthy_threshold = "2"
  }

  tags = {
    Environment = terraform.workspace
    Service     = "service"
  }
}

resource "aws_alb_target_group" "tg-B" {
  name        = "${terraform.workspace}-tg-B"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.vpc.id
  target_type = "ip"

  health_check {
    healthy_threshold   = "3"
    interval            = "30"
    protocol            = "HTTP"
    matcher             = "200"
    timeout             = "3"
    path                = var.health_check_path
    unhealthy_threshold = "2"
  }

  tags = {
    Environment = terraform.workspace
    Service     = "service"
  }
}

# -----------------------------------------
# ALB Listener
# -----------------------------------------
# Create the listener rule to direct all api
# traffic to the correct target group

resource "aws_alb_listener_rule" "api" {
  listener_arn = aws_alb_listener.front_end_ssl.arn
  priority     = 99

  action {
    target_group_arn = aws_alb_target_group.tg-B.id
    type             = "forward"
  }

  condition {
    host_header {
      values = [aws_route53_record.app_record.fqdn]
    }
  }

  lifecycle {
    ignore_changes = [action.0.target_group_arn]
  }
}

# -----------------------------------------
# Task Definition
# -----------------------------------------
# Create the task definition

resource "aws_ecs_task_definition" "tms-api" {
  family                   = "${terraform.workspace}-task"
  task_role_arn            = aws_iam_role.ecs-task-execution-role.arn
  execution_role_arn       = aws_iam_role.ecs-task-execution-role.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.fargate_cpu
  memory                   = var.fargate_memory
  container_definitions    = <<DEFINITION
[
  {
    "image": "${aws_ecr_repository.ecr-repo.repository_url}",
    "name": "${terraform.workspace}-task",
    "network_mode": "awsvpc",
    "environment" : [
        { "name" : "APP_ENV", "value" : "${terraform.workspace}" }
    ],
    "portMappings": [
      {
        "containerPort": ${var.tms_app_port},
        "hostPort": ${var.tms_app_port}
      }
    ],
    "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "${aws_cloudwatch_log_group.alb_log_group.name}",
          "awslogs-region": "${var.aws_region}",
          "awslogs-stream-prefix": "${aws_cloudwatch_log_stream.tms-api.name}"
        }
      }
  }
]
DEFINITION

}

# -----------------------------------------
# Service
# -----------------------------------------
# Create the task definition fargate service

resource "aws_ecs_service" "tms-api" {
  name            = "${terraform.workspace}-tms-api"
  cluster         = aws_ecs_cluster.ecs-cluster.id
  task_definition = aws_ecs_task_definition.tms-api.arn
  desired_count   = var.tms_container_min_count
  launch_type     = "FARGATE"

  lifecycle {
    ignore_changes = [
      task_definition,
      load_balancer,
    ]
  }

  deployment_controller {
    type = "CODE_DEPLOY"
  }


  network_configuration {
    security_groups  = [aws_security_group.lb-sg.id, aws_security_group.db.id]
    subnets          = aws_subnet.private.*.id
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.tg-B.id
    container_name   = aws_ecs_task_definition.tms-api.family
    container_port   = var.tms_app_port
  }

  depends_on = [
    aws_alb_listener.front_end,
    aws_iam_role_policy_attachment.ecs-tasks-exec-role-policy-attach
  ]
}


# -----------------------------------------
# Autoscaling
# -----------------------------------------

resource "aws_appautoscaling_target" "target" {
  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.ecs-cluster.name}/${aws_ecs_service.tms-api.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = var.tms_container_min_count
  max_capacity       = var.tms_container_max_count
  # 6 and 3
}

# Automatically scale capacity up by one
resource "aws_appautoscaling_policy" "up" {
  name               = "${terraform.workspace}_scale_up"
  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.ecs-cluster.name}/${aws_ecs_service.tms-api.name}"
  scalable_dimension = "ecs:service:DesiredCount"

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Maximum"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment          = 1
    }
  }

  depends_on = [aws_appautoscaling_target.target]
}

# Automatically scale capacity down by one
resource "aws_appautoscaling_policy" "down" {
  name               = "${terraform.workspace}_scale_down"
  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.ecs-cluster.name}/${aws_ecs_service.tms-api.name}"
  scalable_dimension = "ecs:service:DesiredCount"

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Maximum"

    step_adjustment {
      metric_interval_upper_bound = 0
      scaling_adjustment          = -1
    }
  }

  depends_on = [aws_appautoscaling_target.target]
}

# CloudWatch alarm that triggers the autoscaling up policy
resource "aws_cloudwatch_metric_alarm" "service_cpu_high" {
  alarm_name          = "${terraform.workspace}_cpu_utilization_high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Average"
  threshold           = "85"

  dimensions = {
    ClusterName = aws_ecs_cluster.ecs-cluster.name
    ServiceName = aws_ecs_service.tms-api.name
  }

  alarm_description = "This metric monitors ecs cpu utilization for auto scaling up"
  alarm_actions     = [aws_appautoscaling_policy.up.arn]
}

# CloudWatch alarm that triggers the autoscaling down policy
resource "aws_cloudwatch_metric_alarm" "service_cpu_low" {
  alarm_name          = "${terraform.workspace}_cpu_utilization_low"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Average"
  threshold           = "10"

  dimensions = {
    ClusterName = aws_ecs_cluster.ecs-cluster.name
    ServiceName = aws_ecs_service.tms-api.name
  }

  alarm_description = "This metric monitors ecs cpu utilization for auto scaling down"
  alarm_actions     = [aws_appautoscaling_policy.down.arn]
}

# -----------------------------------------
# Cloudwatch Logs
# -----------------------------------------
# Create the log

resource "aws_cloudwatch_log_stream" "tms-api" {
  name           = "${terraform.workspace}-service"
  log_group_name = aws_cloudwatch_log_group.alb_log_group.name
}