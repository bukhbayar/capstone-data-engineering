# Task execution role (pull images, send logs)
resource "aws_iam_role" "task_execution" {
  name = "${local.name}-exec-role"
  assume_role_policy = jsonencode({
    Version="2012-10-17",
    Statement=[{
      Effect="Allow",
      Principal={Service="ecs-tasks.amazonaws.com"},
      Action="sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "task_exec_attach" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Service role for Batch
resource "aws_iam_role" "batch_service" {
  name = "${local.name}-service-role"
  assume_role_policy = jsonencode({
    Version="2012-10-17",
    Statement=[{
      Effect="Allow",
      Principal={Service="batch.amazonaws.com"},
      Action="sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "batch_service_attach" {
  role       = aws_iam_role.batch_service.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBatchServiceRole"
}


resource "aws_iam_role" "task_role" {
  name = "${local.name}-task-role"
  assume_role_policy = jsonencode({
    Version="2012-10-17",
    Statement=[{Effect="Allow",
    Principal={Service="ecs-tasks.amazonaws.com"},
    Action="sts:AssumeRole"}]
  })
}

# Logs
resource "aws_cloudwatch_log_group" "batch" {
  name              = "/aws/batch/${local.name}"
  retention_in_days = 7
}
