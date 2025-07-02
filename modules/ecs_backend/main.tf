########################
# ECS
########################

# Define ECS task definition
resource "aws_ecs_task_definition" "backend" {
  family                   = "${var.common.env}-backend-def"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 512
  memory                   = 1024
  network_mode             = "awsvpc"
  execution_role_arn       = aws_iam_role.task_execution_role.arn
  task_role_arn            = aws_iam_role.task_role.arn
  container_definitions = jsonencode([
    {
      name      = "app"
      image     = "${var.common.account_id}.dkr.ecr.ap-northeast-1.amazonaws.com/${var.common.env}-backend:v1"
      cpu       = 256
      memory    = 512
      essential = true
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
      "readonlyRootFilesystem" : false
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-region : "ap-northeast-1"
          awslogs-group : aws_cloudwatch_log_group.backend.name
          awslogs-stream-prefix : "ecs"
        }
      }
    }
  ])
}

# Define ECS cluster
resource "aws_ecs_cluster" "backend" {
  name = "${var.common.env}-backend-cluster"
  setting {
    name  = "containerInsights"
    value = "enhanced"
  }
}

# Define ECS service
resource "aws_ecs_service" "backend" {
  name                               = "${var.common.env}-ecs-backend-service"
  cluster                            = aws_ecs_cluster.backend.arn
  task_definition                    = aws_ecs_task_definition.backend.arn
  launch_type                        = "FARGATE"
  platform_version                   = "1.4.0"
  scheduling_strategy                = "REPLICA"
  desired_count                      = 2
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200
  enable_execute_command = true
  deployment_controller {
    type = "CODE_DEPLOY"
  }
  enable_ecs_managed_tags = true
  network_configuration {
    subnets = var.network.private_subnet_for_container_ids
    security_groups = [
      var.network.security_group_for_backend_container_id
    ]
    assign_public_ip = false
  }
  health_check_grace_period_seconds = 120
  load_balancer {
    target_group_arn = var.alb_internal.alb_target_group_internal_blue_arn
    container_name   = "app"
    container_port   = 80
  }
  lifecycle {
    ignore_changes = [
      task_definition
    ]
  }
}

# Define ECS task execution role
resource "aws_iam_role" "task_execution_role" {
  name               = "${var.common.env}-backend-task-execution-role"
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
  name   = "${var.common.env}-GettingSecretsPolicy-backend"
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

# Define TaskRole for ECS
resource "aws_iam_role" "task_role" {
  name               = "${var.common.env}-backend-task-role"
  assume_role_policy = data.aws_iam_policy_document.trust_policy_for_task_role.json
}

data "aws_iam_policy_document" "trust_policy_for_task_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role_policy_attachment" "policy_management" {
  for_each = {
    ssm = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }
  role       = aws_iam_role.task_role.name
  policy_arn = each.value
}

# Define CloudWatch log group for ECS
resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/${var.common.env}-backend"
  retention_in_days = 14

  tags = {
    Name = "/ecs/${var.common.env}-backend"
  }
}

########################
# CodeConnection
########################

# Define CodeConnection for GitHub Repository
data "aws_codestarconnections_connection" "github" {
  arn = var.code_pipeline.code_connection_arn
}

########################
# CodePipeline
########################

# Define CodePipeline
resource "aws_codepipeline" "backend" {
  name           = "${var.common.env}-backend-codepipeline"
  role_arn       = aws_iam_role.codepipeline.arn
  pipeline_type  = "V2"
  execution_mode = "QUEUED"

  artifact_store {
    location = aws_s3_bucket.codepipeline.bucket
    type     = "S3"
  }

  trigger {
    provider_type = "CodeStarSourceConnection"
    git_configuration {
      source_action_name = "Source"
      push {
        branches {
          includes = [var.code_pipeline.github_repository_branch_name]
        }
        file_paths {
          includes = ["backend_app/handler/*.go"]
        }
      }
    }
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["SourceArtifact"]

      configuration = {
        ConnectionArn    = data.aws_codestarconnections_connection.github.arn
        FullRepositoryId = "${var.code_pipeline.github_repository_owner}/${var.code_pipeline.github_repository_name}"
        BranchName       = var.code_pipeline.github_repository_branch_name
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["SourceArtifact"]
      output_artifacts = ["BuildArtifact"]

      configuration = {
        ProjectName = aws_codebuild_project.backend.name
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeployToECS"
      version         = "1"
      input_artifacts = ["BuildArtifact"]

      configuration = {
        ApplicationName                = aws_codedeploy_app.backend.name
        DeploymentGroupName            = aws_codedeploy_deployment_group.backend.deployment_group_name
        TaskDefinitionTemplateArtifact = "BuildArtifact"
        AppSpecTemplateArtifact        = "BuildArtifact"
        Image1ArtifactName             = "BuildArtifact"
        Image1ContainerName            = "IMAGE1_NAME"
      }
    }
  }
}

# Define IAM service role for CodePipeline
resource "aws_iam_role" "codepipeline" {
  name               = "${var.common.env}-role-for-codepipeline"
  assume_role_policy = data.aws_iam_policy_document.trust_policy_for_codepipeline.json
}

data "aws_iam_policy_document" "trust_policy_for_codepipeline" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_policy" "policy_for_codepipeline" {
  name = "${var.common.env}-policy-for-codepipeline"
  policy = templatefile("../../iam_policy_json_files/policy_for_codepipeline.json", {
    pipeline_arn = aws_codepipeline.backend.arn
  })
}

resource "aws_iam_role_policy_attachment" "policy_for_codepipeline" {
  for_each = {
    codepipeline = aws_iam_policy.policy_for_codepipeline.arn
  }
  role       = aws_iam_role.codepipeline.name
  policy_arn = each.value
}

# Define S3 Bucket for Artifacts
resource "aws_s3_bucket" "codepipeline" {
  bucket = var.code_pipeline.artifacts_bucket_name
}

resource "aws_s3_bucket_versioning" "codepipeline" {
  bucket = aws_s3_bucket.codepipeline.bucket
  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_bucket_public_access_block" "codepipeline" {
  bucket                  = aws_s3_bucket.codepipeline.bucket
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "codepipeline" {
  bucket = aws_s3_bucket.codepipeline.bucket
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

########################
# CodeBuild
########################

# Define CodeBuild project
resource "aws_codebuild_project" "backend" {
  name         = "${var.common.env}-backend-codebuild"
  service_role = aws_iam_role.codebuild.arn

  source {
    type     = "GITHUB"
    location = "https://github.com/${var.code_pipeline.github_repository_owner}/${var.code_pipeline.github_repository_name}"
  }

  artifacts {
    type     = "S3"
    location = aws_s3_bucket.codepipeline.bucket
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/amazonlinux-x86_64-standard:5.0"
    type         = "LINUX_CONTAINER"
    environment_variable {
      name  = "REGION"
      value = var.common.region
    }
    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = var.common.account_id
    }
    environment_variable {
      name  = "DOCKER_USERNAME"
      value = var.code_pipeline.docker_username
    }
    environment_variable {
      name  = "DOCKER_PASSWORD"
      value = var.code_pipeline.docker_password
    }
    environment_variable {
      name  = "REPOSITORY_URI"
      value = var.ecr_repository.backend_repository_uri
    }
    environment_variable {
      name  = "TASK_FAMILY"
      value = "${var.common.env}-backend-def"
    }
    environment_variable {
      name  = "TASK_EXECUTION_ROLE_ARN"
      value = aws_iam_role.task_execution_role.arn
    }
    environment_variable {
      name = "TASK_ROLE_ARN"
      value = aws_iam_role.task_role.arn
    }
    environment_variable {
      name  = "SECRETS_FOR_DB_ARN"
      value = var.secrets_manager.secret_for_db_arn
    }
    environment_variable {
      name  = "LOG_GROUP_NAME"
      value = aws_cloudwatch_log_group.backend.name
    }
  }
}

# Define IAM sevice role for CodeBuild
resource "aws_iam_role" "codebuild" {
  name               = "${var.common.env}-role-for-codebuild"
  assume_role_policy = data.aws_iam_policy_document.trust_policy_for_codebuild.json
}

data "aws_iam_policy_document" "trust_policy_for_codebuild" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_policy" "policy_for_codebuild" {
  name = "${var.common.env}-policy-for-codebuild"
  policy = templatefile("../../iam_policy_json_files/policy_for_codebuild.json", {
    region        = var.common.region,
    account_id    = var.common.account_id,
    project_name  = aws_codebuild_project.backend.name
    s3_bucket_arn = aws_s3_bucket.codepipeline.arn
  })
}

resource "aws_iam_role_policy_attachment" "codebuild" {
  for_each = {
    codebuild      = aws_iam_policy.policy_for_codebuild.arn
    secretsmanager = aws_iam_policy.policy_for_access_to_secrets_manager.arn
    ecr            = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
  }
  role       = aws_iam_role.codebuild.name
  policy_arn = each.value
}

########################
# CodeDeploy
########################

# Define CodeDeploy application
resource "aws_codedeploy_app" "backend" {
  compute_platform = "ECS"
  name             = "${var.common.env}-backend-app"
}

# Define CodeDeploy deployment group
resource "aws_codedeploy_deployment_group" "backend" {
  app_name               = aws_codedeploy_app.backend.name
  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"
  deployment_group_name  = "${var.common.env}-ecs-backend-deployment-group"
  service_role_arn       = aws_iam_role.codedeploy.arn
  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }
  ecs_service {
    cluster_name = aws_ecs_cluster.backend.name
    service_name = aws_ecs_service.backend.name
  }
  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [var.alb_internal.alb_listener_internal_prod_arn]
      }
      test_traffic_route {
        listener_arns = [var.alb_internal.alb_listener_internal_test_arn]
      }
      target_group {
        name = var.alb_internal.alb_target_group_internal_blue_name
      }
      target_group {
        name = var.alb_internal.alb_target_group_internal_green_name
      }
    }
  }
  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout    = "STOP_DEPLOYMENT"
      wait_time_in_minutes = 10
    }
    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 60
    }
  }
}

# Define IAM role for CodeDeploy
resource "aws_iam_role" "codedeploy" {
  name               = "${var.common.env}-role-for-codedeploy"
  assume_role_policy = data.aws_iam_policy_document.trust_policy_for_codedeploy.json
}

data "aws_iam_policy_document" "trust_policy_for_codedeploy" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["codedeploy.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role_policy_attachment" "codedeploy" {
  for_each = {
    codedeploy = "arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS"
  }
  role       = aws_iam_role.codedeploy.name
  policy_arn = each.value
}
