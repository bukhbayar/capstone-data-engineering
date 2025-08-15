resource "aws_security_group" "sg_airflow" {
  name        = "${local.name}-airflow-sg"
  description = "inbound and outbound rules"
  vpc_id      = module.network.vpc_id

  ingress {
    description = "Allow  inbound"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name}-airflow-sg"
  }
}

resource "aws_security_group" "sg_postgres" {
  name        = "${local.name}-postgres-sg"
  description = "inbound and outbound rules"
  vpc_id      = module.network.vpc_id

  ingress {
    description = "Allow  inbound"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name}-postgres-sg"
  }
}