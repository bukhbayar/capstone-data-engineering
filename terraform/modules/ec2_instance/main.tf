resource "aws_instance" "this" {
  ami                         = "ami-0deeb71371199f16f"
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = var.security_group_ids
  iam_instance_profile        = aws_iam_instance_profile.profile.name
  associate_public_ip_address = true

  key_name                    = "demo-key"
  user_data                   = local.user_data

  private_ip                  = var.private_ip

  tags = {
    Name        = var.role_name
    Project     = var.project
    Environment = var.environment
  }
}

resource "null_resource" "remote_commands" {
  count = var.airflow_scripts!="" ? 1 : 0

  connection {
    type        = "ssh"
    host        = aws_instance.this.public_ip
    user        = "ec2-user"
    private_key = var.ssh_private_key
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Executing remote-exec provisioner...'",
      "${var.airflow_scripts}"
    ]
  }

  depends_on = [aws_instance.this]
}