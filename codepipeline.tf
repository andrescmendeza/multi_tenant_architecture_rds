# -----------------------------------------
# S3 Bucket
# -----------------------------------------
# Create the S3 bucket for handling pipeline deploys

resource "aws_s3_bucket" "tms_s3_bucket" {
  bucket        = "${terraform.workspace}-tms-pipeline"
  force_destroy = true
}

resource "aws_s3_bucket_acl" "s3_bucket_acl" {
  bucket = aws_s3_bucket.tms_s3_bucket.id
  acl    = "private"
}


# Encryption key for build artifacts
resource "aws_kms_key" "tms_s3_kms_key" {
  description             = "${terraform.workspace}-tms-artifact-encryption-key"
  deletion_window_in_days = 10
}

# -----------------------------------------
# TMS Codecommit Repository
# -----------------------------------------
# Get the codecommit repository
data "aws_codecommit_repository" "tms" {
  repository_name = var.tms_repo_name
}

# -----------------------------------------
# TMS Codebuild Log Group
# -----------------------------------------
resource "aws_cloudwatch_log_group" "tms_build_logs" {
  name              = "/aws/codebuild/${aws_codebuild_project.tms.name}"
  retention_in_days = var.cloudwatch_log_retention
}

# -----------------------------------------
# Pipeline Role/Policy
# -----------------------------------------
# Create the role/policy for handing the code pipeline


resource "aws_iam_role" "event_pipeline_role" {
  name = "${terraform.workspace}-event-pipeline-role"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "events.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF

}



# Create the role trusted provicers
resource "aws_iam_role" "tms_pipeline_role" {
  name = "${terraform.workspace}-tms-pipeline-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "codepipeline.amazonaws.com",
          "codebuild.amazonaws.com",
          "codedeploy.amazonaws.com",
          "codecommit.amazonaws.com",
          "events.amazonaws.com"
        ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

}

# Create the default policy attachment for code pipeline
resource "aws_iam_role_policy" "tms_pipeline_default_policy" {
  name = "${terraform.workspace}-tms-pipeline-default-policy"
  role = aws_iam_role.tms_pipeline_role.id

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "iam:PassRole"
            ],
            "Resource": "*",
            "Effect": "Allow",
            "Condition": {
                "StringEqualsIfExists": {
                    "iam:PassedToService": [
                        "cloudformation.amazonaws.com",
                        "elasticbeanstalk.amazonaws.com",
                        "ec2.amazonaws.com",
                        "ecs-tasks.amazonaws.com"
                    ]
                }
            }
        },
        {
            "Action": [
                "codedeploy:CreateDeployment",
                "codedeploy:GetApplication",
                "codedeploy:GetApplicationRevision",
                "codedeploy:GetDeployment",
                "codedeploy:GetDeploymentConfig",
                "codedeploy:RegisterApplicationRevision"
            ],
            "Resource": "*",
            "Effect": "Allow"
        },
        {
            "Action": [
                "elasticbeanstalk:*",
                "ec2:*",
                "elasticloadbalancing:*",
                "autoscaling:*",
                "cloudwatch:*",
                "s3:*",
                "sns:*",
                "cloudformation:*",
                "rds:*",
                "sqs:*",
                "ecs:*"
            ],
            "Resource": "*",
            "Effect": "Allow"
        },
        {
            "Action": [
                "lambda:InvokeFunction",
                "lambda:ListFunctions"
            ],
            "Resource": "*",
            "Effect": "Allow"
        },
        {
            "Action": [
                "opsworks:CreateDeployment",
                "opsworks:DescribeApps",
                "opsworks:DescribeCommands",
                "opsworks:DescribeDeployments",
                "opsworks:DescribeInstances",
                "opsworks:DescribeStacks",
                "opsworks:UpdateApp",
                "opsworks:UpdateStack"
            ],
            "Resource": "*",
            "Effect": "Allow"
        },
        {
            "Action": [
                "cloudformation:CreateStack",
                "cloudformation:DeleteStack",
                "cloudformation:DescribeStacks",
                "cloudformation:UpdateStack",
                "cloudformation:CreateChangeSet",
                "cloudformation:DeleteChangeSet",
                "cloudformation:DescribeChangeSet",
                "cloudformation:ExecuteChangeSet",
                "cloudformation:SetStackPolicy",
                "cloudformation:ValidateTemplate"
            ],
            "Resource": "*",
            "Effect": "Allow"
        },
        {
            "Action": [
                "codebuild:BatchGetBuilds",
                "codebuild:StartBuild"
            ],
            "Resource": "*",
            "Effect": "Allow"
        },
        {
            "Effect": "Allow",
            "Action": [
                "devicefarm:ListProjects",
                "devicefarm:ListDevicePools",
                "devicefarm:GetRun",
                "devicefarm:GetUpload",
                "devicefarm:CreateUpload",
                "devicefarm:ScheduleRun"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "servicecatalog:ListProvisioningArtifacts",
                "servicecatalog:CreateProvisioningArtifact",
                "servicecatalog:DescribeProvisioningArtifact",
                "servicecatalog:DeleteProvisioningArtifact",
                "servicecatalog:UpdateProduct"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "cloudformation:ValidateTemplate"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ecr:DescribeImages"
            ],
            "Resource": "*"
        }
    ]
}
EOF

}

# create the pipeline policy for the TMS
resource "aws_iam_role_policy" "tms_pipeline_policy" {
  name = "${terraform.workspace}-tms-pipeline-policy"
  role = aws_iam_role.tms_pipeline_role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Resource": [
        "${aws_cloudwatch_log_group.tms_build_logs.arn}:*"
      ],
      "Action": [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": [
        "${aws_cloudwatch_log_group.tms_build_logs.arn}:*"
      ]
    },
    {
      "Action": [
          "codecommit:GetBranch",
          "codecommit:GetCommit",
          "codecommit:UploadArchive",
          "codecommit:GetUploadArchiveStatus",
          "codecommit:CancelUploadArchive"
        ],
      "Resource": "${data.aws_codecommit_repository.tms.arn}",
      "Effect": "Allow"
    },
    {
      "Effect":"Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": [
        "${aws_s3_bucket.tms_s3_bucket.arn}",
        "${aws_s3_bucket.tms_s3_bucket.arn}/*",
        "arn:aws:s3:::eluma.environments*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:CompleteLayerUpload",
        "ecr:InitiateLayerUpload",
        "ecr:PutImage",
        "ecr:UploadLayerPart"
      ],
      "Resource": "${aws_ecr_repository.ecr-repo.arn}"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer",
        "ecr:InitiateLayerUpload",
        "ecr:CompleteLayerUpload"
      ],
      "Resource": "${data.aws_ecr_repository.tms_base_image.arn}"
    },

    {
            "Effect": "Allow",
            "Action": [
               "secretsmanager:DescribeSecret",
               "secretsmanager:GetResourcePolicy",
                "secretsmanager:GetSecretValue"
            ],
            
            "Resource" : "arn:aws:secretsmanager:us-west-2:951409643364:secret:tms-jo8JxK"
    },

    {
        "Effect": "Allow",
        "Action": [
            "kms:*"
        ],
        
        "Resource": "${aws_kms_key.tms_s3_kms_key.arn}"
    },
    {
            "Effect": "Allow",
            "Action": [
                "ssm:DescribeParameters"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ssm:GetParameters"
            ],
            "Resource": "arn:aws:ssm:${var.aws_region}:${var.aws_account_id}:parameter/${terraform.workspace}/*"
        }
  ]
}
EOF

}



# -----------------------------------------
# Event Rule to Trigger code pipeline
# -----------------------------------------
resource "aws_iam_role_policy" "tms_event_pipeline_policy" {
  name = "${terraform.workspace}-tms-event-pipeline-policy"
  role = aws_iam_role.event_pipeline_role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
          "Effect": "Allow",
          "Action": [
              "codepipeline:StartPipelineExecution"
          ],
          "Resource": [
              "${aws_codepipeline.tms_pipeline.arn}"
          ]
      }
  ]
}
EOF

}

resource "aws_cloudwatch_event_rule" "trigger_tms_pipeline" {
  name          = "${terraform.workspace}-tms-trigger-pipeline"
  description   = "Trigger the TMS Pipeline to run on source change"
  event_pattern = <<PATTERN
{
  "source": [ "aws.codecommit" ],
  "detail-type": [ "CodeCommit Repository State Change" ],
  "resources": [ "${data.aws_codecommit_repository.tms.arn}" ],
  "detail": {
     "event": [
       "referenceCreated",
       "referenceUpdated"],
     "referenceType":["branch"],
     "referenceName": ["${var.tms_repo_branch}"]
  }
}
PATTERN

}

resource "aws_cloudwatch_event_target" "tms_sns" {
  rule      = aws_cloudwatch_event_rule.trigger_tms_pipeline.name
  target_id = "TriggerTMSPipeline"
  arn       = aws_codepipeline.tms_pipeline.arn
  role_arn  = aws_iam_role.event_pipeline_role.arn
}

# -----------------------------------------
# The Code Pipeline
# -----------------------------------------
# Create the pipeline

resource "aws_codepipeline" "tms_pipeline" {
  name     = "${terraform.workspace}-tms-pipeline"
  role_arn = aws_iam_role.tms_pipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.tms_s3_bucket.bucket
    type     = "S3"

    encryption_key {
      id   = aws_kms_key.tms_s3_kms_key.arn
      type = "KMS"
    }
  }

  stage {
    name = "Source"

    action {
      name     = "Source"
      category = "Source"
      owner    = "AWS"
      provider = "CodeCommit"
      version  = "1"
      output_artifacts = [
        "SourceArtifact",
      ]

      configuration = {
        RepositoryName       = var.tms_repo_name
        BranchName           = var.tms_repo_branch
        PollForSourceChanges = "false"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name     = "Build"
      category = "Build"
      owner    = "AWS"
      provider = "CodeBuild"
      input_artifacts = [
        "SourceArtifact",
      ]
      output_artifacts = [
        "BuildArtifact"
      ]
      version = "1"

      configuration = {
        ProjectName = "${terraform.workspace}-tms-build"
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
      input_artifacts = ["BuildArtifact"]
      version         = "1"

      configuration = {
        ApplicationName                = aws_codedeploy_app.tms.name
        DeploymentGroupName            = aws_codedeploy_deployment_group.tms.deployment_group_name
        TaskDefinitionTemplateArtifact = "BuildArtifact"
        TaskDefinitionTemplatePath     = "taskdef.json"
        AppSpecTemplateArtifact        = "BuildArtifact"
        AppSpecTemplatePath            = "appspec.yaml"
      }
    }

  }

  depends_on = [
    aws_codebuild_project.tms,
    aws_codedeploy_app.tms,
    aws_codedeploy_deployment_group.tms,
  ]
}

# -----------------------------------------
# Codebuild
# -----------------------------------------
# Create the codebuild roles/policies and project

resource "aws_codebuild_project" "tms" {
  name           = "${terraform.workspace}-tms-build"
  description    = "The CodeBuild project for ${aws_ecr_repository.ecr-repo.name}"
  service_role   = aws_iam_role.tms_pipeline_role.arn
  build_timeout  = var.build_timeout
  encryption_key = aws_kms_key.tms_s3_kms_key.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type    = var.tms_compute_type
    image           = var.build_image
    type            = "LINUX_CONTAINER"
    privileged_mode = var.build_privileged_override

    environment_variable {
      name  = "APP_ENV"
      value = terraform.workspace
    }

    environment_variable {
      name  = "FAMILY"
      value = aws_ecs_task_definition.tms-api.family
    }

    environment_variable {
      name  = "CONTAINER_NAME"
      value = aws_ecs_task_definition.tms-api.family
    }

    environment_variable {
      name  = "CPU"
      value = var.tms_cpu
    }

    environment_variable {
      name  = "MEMORY"
      value = var.tms_memory
    }

    environment_variable {
      name  = "TASK_ROLE_ARN"
      value = aws_iam_role.ecs-task-execution-role.arn
    }

    environment_variable {
      name  = "EXECUTION_ROLE_ARN"
      value = aws_iam_role.ecs-task-execution-role.arn
    }

    environment_variable {
      name  = "CONTAINER_PORT"
      value = var.tms_app_port
    }

    environment_variable {
      name  = "HOST_PORT"
      value = var.tms_app_port
    }

    environment_variable {
      name  = "LOG_STREAM_PREFIX"
      value = aws_cloudwatch_log_stream.tms-api.name
    }

    environment_variable {
      name  = "CACHE_PREFIX"
      value = "${terraform.workspace}_tms"
    }

    environment_variable {
      name  = "PM"
      value = var.tms_pm
    }

    environment_variable {
      name  = "PM_MAX_CHILDREN"
      value = var.tms_pm_max_children
    }

    environment_variable {
      name  = "PM_START_SERVERS"
      value = var.tms_pm_start_servers
    }

    environment_variable {
      name  = "PM_MIN_SPARE_SERVERS"
      value = var.tms_pm_min_spare_servers
    }

    environment_variable {
      name  = "PM_MAX_SPARE_SERVERS"
      value = var.tms_pm_max_spare_servers
    }

    environment_variable {
      name  = "PM_MAX_REQUESTS"
      value = var.tms_pm_max_requests
    }

    environment_variable {
      name  = "REPOSITORY_URI"
      value = "951409643364.dkr.ecr.us-west-2.amazonaws.com/${terraform.workspace}-tms-api"
    }

    environment_variable {
      name  = "APP_NAME"
      value = "${terraform.workspace}-tms"
    }

    environment_variable {
      name  = "BRANCH"
      value = terraform.workspace
    }

    environment_variable {
      name  = "REDIS"
      value = "${terraform.workspace}-cache-rep-group-002.qrllb5.0001.use1.cache.amazonaws.com"
    }

    environment_variable {
      name  = "DB_HOST"
      value = "${terraform.workspace}-tms-db.c5nqdntt4vpl.${var.aws_region}.rds.amazonaws.com"
    }

    environment_variable {
      name  = "APP_URL"
      value = "https://${terraform.workspace}-tms-api.elumasass.com"
    }

    environment_variable {
      name  = "FRONT_URL"
      value = "https://${terraform.workspace}-tms.elumasass.com"
    }

    environment_variable {
      name  = "MAX_SIZE_UPLOAD"
      value = "102400"
    }

    environment_variable {
      name  = "ACTIVATE_ACCOUNT_EXPIRE"
      value = "10080"
    }

    environment_variable {
      name  = "ACTIVATE_ACCOUNT_THROTTLE"
      value = "10080"
    }

    environment_variable {
      name  = "MIN_RECORDS_TO_QUEUE"
      value = "1000"
    }

    environment_variable {
      name  = "REGION"
      value = var.aws_region
    }

    environment_variable {
      name  = "LOG_GROUP"
      value = aws_cloudwatch_log_group.alb_log_group.name
    }

  }

  source {
    type      = "CODEPIPELINE"
    buildspec = var.buildspec_file
  }
}


# -----------------------------------------
# Codedeploy
# -----------------------------------------
# Create the codebuild roles/policies and project
resource "aws_codedeploy_app" "tms" {
  compute_platform = "ECS"
  name             = "${terraform.workspace}-tms"
}

resource "aws_codedeploy_deployment_group" "tms" {
  app_name               = aws_codedeploy_app.tms.name
  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"
  deployment_group_name  = "${terraform.workspace}-tms"
  service_role_arn       = aws_iam_role.tms_pipeline_role.arn

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }

    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 5
    }
  }

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  ecs_service {
    cluster_name = aws_ecs_cluster.ecs-cluster.name
    service_name = aws_ecs_service.tms-api.name
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [aws_alb_listener.front_end_ssl.arn]
      }

      target_group {
        name = aws_alb_target_group.tg-A.name
      }

      target_group {
        name = aws_alb_target_group.tg-B.name
      }
    }
  }
}


