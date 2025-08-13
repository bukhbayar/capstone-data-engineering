resource "aws_instance" "this" {
  ami                         = "ami-0deeb71371199f16f"
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.sg.id]
  iam_instance_profile        = aws_iam_instance_profile.profile.name
  associate_public_ip_address = true

  key_name                    = "demo-key"
  user_data                   = local.user_data

  tags = {
    Name        = local.name
    Project     = var.project
    Environment = var.environment
  }
}
