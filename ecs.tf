
# -----------------------------------------
# ECS Cluster w/Roles
# -----------------------------------------
# Create the target groups for the
# blue/green deployments

resource "aws_ecs_cluster" "ecs-cluster" {
  name = "${terraform.workspace}-cluster"
}

# ECS task execution role data
# The IAM policy for task execution
data "aws_iam_policy_document" "ecs-tasks-exec-role-policy-doc" {
  statement {
    sid     = ""
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# ECS task execution role
resource "aws_iam_role" "ecs-task-execution-role" {
  name               = "${terraform.workspace}-ecs-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs-tasks-exec-role-policy-doc.json
}

# ECS task execution role policy attachment
resource "aws_iam_role_policy_attachment" "ecs-tasks-exec-role-policy-attach" {
  role       = aws_iam_role.ecs-task-execution-role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}