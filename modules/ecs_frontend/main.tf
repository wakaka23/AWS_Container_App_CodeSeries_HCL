########################
# ECS
########################

# Define ECS task definition
resource "aws_ecs_task_definition" "frontend" {
  family                   = "${var.common.env}-frontend-def"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 512
  memory                   = 1024
  network_mode             = "awsvpc"
  execution_role_arn       = aws_iam_role.task_execution_role.arn
  container_definitions = jsonencode([
    {
      name      = "app"
      image     = "${var.common.account_id}.dkr.ecr.ap-northeast-1.amazonaws.com/${var.common.env}-frontend:v1"
      cpu       = 256
      memory    = 512
      essential = true
      environment = [
        {
          name  = "APP_SERVICE_HOST"
          value = "http://${var.alb_internal.alb_internal_dns_name}"
        },
        {
          name  = "NOTIF_SERVICE_HOST"
          value = "http://${var.alb_internal.alb_internal_dns_name}"
        },
        {
          name  = "SESSION_SECRET_KEY"
          value = "41b678c65b37bf99c37bcab522802760"
        },
      ]
      secrets = [
        {
          name      = "DB_HOST"
          valueFrom = "${var.secrets_manager.secret_for_db_arn}:host::"
        },
        {
          name      = "DB_NAME"
          valueFrom = "${var.secrets_manager.secret_for_db_arn}:dbname::"
        },
        {
          name      = "DB_USERNAME"
          valueFrom = "${var.secrets_manager.secret_for_db_arn}:username::"
        },
        {
          name      = "DB_PASSWORD"
          valueFrom = "${var.secrets_manager.secret_for_db_arn}:password::"
        }
      ]
      portMappings = [{ containerPort = 80 }]
      "readonlyRootFilesystem" : true
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-region : "ap-northeast-1"
          awslogs-group : aws_cloudwatch_log_group.frontend.name
          awslogs-stream-prefix : "ecs"
        }
      }
    }
  ])
}

# Define ECS cluster
resource "aws_ecs_cluster" "frontend" {
  name = "${var.common.env}-frontend-cluster"
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# Define ECS service
resource "aws_ecs_service" "frontend" {
  name                               = "${var.common.env}-ecs-frontend-service"
  cluster                            = aws_ecs_cluster.frontend.arn
  task_definition                    = aws_ecs_task_definition.frontend.arn
  launch_type                        = "FARGATE"
  platform_version                   = "1.4.0"
  scheduling_strategy                = "REPLICA"
  desired_count                      = 2
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200
  deployment_controller {
    type = "ECS"
  }
  enable_ecs_managed_tags = true
  network_configuration {
    subnets          = var.network.private_subnet_for_container_ids
    security_groups  = [var.network.security_group_for_frontend_container_id]
    assign_public_ip = false
  }
  health_check_grace_period_seconds = 120
  load_balancer {
    target_group_arn = var.alb_ingress.alb_target_group_ingress_arn
    container_name   = "app"
    container_port   = 80
  }
}

# Define ECS task execution role
resource "aws_iam_role" "task_execution_role" {
  name               = "${var.common.env}-frontend-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.trust_policy_for_task_execution_role.json
}

data "aws_iam_policy_document" "trust_policy_for_task_execution_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_policy" "policy_for_access_to_secrets_manager" {
  name   = "${var.common.env}-GettingSecretsPolicy-frontend"
  policy = data.aws_iam_policy_document.policy_for_access_to_secrets_manager.json
}

data "aws_iam_policy_document" "policy_for_access_to_secrets_manager" {
  statement {
    effect    = "Allow"
    resources = ["*"]
    actions = [
      "secretsmanager:GetSecretValue",
    ]
  }
}

resource "aws_iam_role_policy_attachment" "task_execution_role" {
  for_each = {
    ecs            = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy",
    secretsmanager = aws_iam_policy.policy_for_access_to_secrets_manager.arn
  }
  role       = aws_iam_role.task_execution_role.name
  policy_arn = each.value
}

# Define CloudWatch log group for ECS
resource "aws_cloudwatch_log_group" "frontend" {
  name              = "/ecs/${var.common.env}-frontend"
  retention_in_days = 14

  tags = {
    Name = "/ecs/${var.common.env}-frontend"
  }
}
