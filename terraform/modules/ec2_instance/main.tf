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

resource "terraform_data" "provision_every_apply" {
  count = var.airflow_scripts!="" ? 1 : 0
  # keep this tied to your instance so if it’s replaced, this re-runs too
  input = {
    instance_id = aws_instance.this.id
  }

  # the magic: any change here forces replacement → provisioners run again
  triggers_replace = timestamp()

  connection {
    host        = aws_instance.this.private_ip
    user        = "ec2-user"          # or "ubuntu", etc
    private_key = var.ssh_private_key
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Hello from remote-exec at $(date)' | sudo tee /tmp/hello.txt",
      "${var.airflow_scripts}"
    ]
  }

  depends_on = [aws_instance.this]
}