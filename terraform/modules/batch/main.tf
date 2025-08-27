# Interface endpoints
locals { ifaces = ["ecr.api","ecr.dkr","logs","sts"] }
resource "aws_vpc_endpoint" "ifaces" {
  for_each            = toset([for s in local.ifaces : "com.amazonaws.${var.aws_region}.${s}"])
  vpc_id              = var.vpc_id
  service_name        = each.value
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.batch.id]
}

# Gateway endpoint for S3
resource "aws_vpc_endpoint" "s3_gw" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.private_route_table_ids
}

# Compute Environment (Fargate)
resource "aws_batch_compute_environment" "fargate" {
  compute_environment_name = "${local.name}-ce"
  service_role             = aws_iam_role.batch_service.arn
  type                     = "MANAGED"
  state                    = "ENABLED"

  compute_resources {
    type                = "FARGATE"
    max_vcpus           = 64
    subnets             = var.private_subnet_ids
    security_group_ids  = [aws_security_group.batch.id]
  }

  # Optional spot CE for cheaper runs
  depends_on = [aws_iam_role_policy_attachment.batch_service_attach]
}

resource "aws_batch_job_queue" "queue" {
  name                 = "${local.name}-queue"
  state                = "ENABLED"
  priority             = 1

  compute_environment_order {
    order               = 1
    compute_environment = aws_batch_compute_environment.fargate.arn
  }
}

# Job Definition (dbt “ready”)
resource "aws_batch_job_definition" "dbt" {
  name                  = "${local.name}-dbt"
  type                  = "container"
  platform_capabilities = ["FARGATE"]
  container_properties  = jsonencode({
    image     : var.dbt_container_image,
    command   : ["--version"],  # replace with your dbt command
    fargatePlatformConfiguration : { platformVersion : "LATEST" },
    resourceRequirements : [
      { type : "VCPU",   value : tostring(var.dbt_vcpu) },
      { type : "MEMORY", value : tostring(var.dbt_memory) }
    ],
    logConfiguration : {
      logDriver : "awslogs",
      options   : {
        "awslogs-group"         : "${aws_cloudwatch_log_group.batch.name}",
        "awslogs-region"        : "${var.aws_region}",
        "awslogs-stream-prefix" : "dbt"
      }
    },
    executionRoleArn : "${aws_iam_role.task_execution.arn}",
    jobRoleArn       : "${aws_iam_role.task_role.arn}",
    networkConfiguration : { assignPublicIp : "DISABLED" }
  })
}