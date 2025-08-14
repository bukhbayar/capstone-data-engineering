# SG for Batch tasks (egress only)
resource "aws_security_group" "batch" {
  name        = "${local.name}-sg"
  description = "Batch Fargate tasks egress"
  vpc_id      = var.vpc_id

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name}-sg"
  }
}
