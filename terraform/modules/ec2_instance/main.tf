resource "aws_instance" "this" {
  ami                         = "ami-010876b9ddd38475e"
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.sg.id]
  iam_instance_profile        = aws_iam_instance_profile.profile.name
  associate_public_ip_address = false

  tags = {
    Name        = local.name
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_iam_role" "role" {
  name = "${local.name}-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "profile" {
  name = "${local.name}-profile"
  role = aws_iam_role.role.name
}

resource "aws_security_group" "sg" {
  name        = "${local.name}-sg"
  description = "inbound and outbound rules"
  vpc_id      = var.vpc_id

  egress {
    description = "Allow https outbound"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow https inbound"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name}-sg"
  }
}
