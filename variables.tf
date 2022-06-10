# variables.tf

/*
|--------------------------------------------------------------------------
| General Variables
|--------------------------------------------------------------------------
*/

variable "aws_region" {
  description = "The AWS region things are created in"
  default     = "us-west-2"
}

variable "ecs_task_execution_role_name" {
  description = "ECS task execution role name"
  default     = "myEcsTaskExecutionRole"
}

variable "aws_account_id" {
  description = "The AWS account id"
  default     = "951409643364"
}

variable "domain" {
  description = "Domain Register"
  default     = "elumasass.com"
}


/*
|--------------------------------------------------------------------------
| Network variables
|--------------------------------------------------------------------------
*/

variable "vpc_cidr" {
  description = "The cidr for the vpc"
  default     = "172.17.0.0/16"
}

variable "vpc_public_az_count" {
  description = "The amount of availability zones for the VPC"
  default     = 2
}

variable "vpc_private_az_count" {
  description = "The amount of availability zones for the VPC"
  default     = 2
}

variable "tcp_port1" {
  description = "Port exposed by the docker image to redirect traffic to"
  default     = 80
}

variable "tcp_port2" {
  description = "Port exposed by the docker image to redirect traffic to"
  default     = 443
}




/*
|--------------------------------------------------------------------------
| Service variables
|--------------------------------------------------------------------------
*/

variable "app_count" {
  description = "Number of docker containers to run"
  default     = 3
}

variable "health_check_path" {
  default = "/health-check"
}

variable "fargate_cpu" {
  description = "Fargate instance CPU units to provision (1 vCPU = 1024 CPU units)"
  default     = "1024"
}

variable "fargate_memory" {
  description = "Fargate instance memory to provision (in MiB)"
  default     = "2048"
}

variable "cloudwatch_log_retention" {
  default = 14
}

variable "tms_app_port" {
  description = "Port exposed by the docker image to redirect traffic to"
  default     = 80
}

variable "tms_container_min_count" {
  description = "The minimum amount of containters to run for the api application"
  default     = 1
}

variable "tms_container_max_count" {
  description = "The maximum amount of containters to run for the api application"
  default     = 4
}


/*
|--------------------------------------------------------------------------
| Database
|--------------------------------------------------------------------------
*/

variable "db_username" {
  description = "The database username for creating"

}

variable "db_password" {
  description = "The database password for creating"
  
}

variable "db_license_model" {
  default     = "general-public-license"
  description = "License model of the DB instance"
}

/*
|--------------------------------------------------------------------------
| Api Variables: BackEnd
|--------------------------------------------------------------------------
*/

variable "tms_memory" {
  description = "Fargate instance memory to provision (in MiB)"
  default     = "5120"
}

variable "tms_cpu" {
  description = "Fargate instance CPU units to provision (1 vCPU = 1024 CPU units)"
  default     = "2048"
}

variable "tms_repo_name" {
  description = "The codecommit repository name"
  default     = "tms-api"
}

variable "tms_repo_branch" {
  description = "The source branch"
  default     = "feature"
}

variable "ecr_tms_base_image" {
  description = "The ECR repository for the base image"
  default     = "tms-base"
}

variable "tms_pm_max_requests" {
  description = "PHP-FPM max requests per process"
  default     = 500
}

variable "tms_pm_max_spare_servers" {
  description = "PHP-FPM max spare servers # cores x 4"
  default     = 15
}

variable "tms_pm_min_spare_servers" {
  description = "PHP-FPM min spare servers # cores x 2"
  default     = 15
}

variable "tms_pm_start_servers" {
  description = "PHP-FPM start servers # cores x 4"
  default     = 10
}

variable "tms_pm_max_children" {
  description = "PHP-FPM max childeren (tms_memory - (tms_memory * .2) / 65)"
  default     = 15
}

variable "tms_pm" {
  description = "static | dynamic | ondemand"
  default     = "dynamic"
}

/*
|--------------------------------------------------------------------------
| Api Variables: FrontEnd
|--------------------------------------------------------------------------
*/

variable "ui_repository" {
  description = "The codecommit repository name"
  default     = "https://bitbucket.org/elumatherapy/ui-insight/src/master"
}



/*
|--------------------------------------------------------------------------
| Codebuild variables
|--------------------------------------------------------------------------
*/

variable "tms_compute_type" {
  description = "The image identifier of the Docker image to use for this build project"
  default     = "BUILD_GENERAL1_SMALL"
}

variable "build_timeout" {
  description = "The amount of minutes before the build times out. Max 480 (8 hours)"
  default     = "90"
}

variable "buildspec_file" {
  description = "The buildspec file for the source build"
  default     = "buildspec.yml"
}

variable "build_image" {
  description = "The image identifier of the Docker image to use for this build project"
  default     = "aws/codebuild/standard:4.0"
}

variable "build_privileged_override" {
  description = "If set to true, enables running the Docker daemon inside a Docker container."
  default     = "true"
}

