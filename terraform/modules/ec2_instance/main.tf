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
  count = var.enable_airflow_seed ? 1 : 0

  triggers = {
    instance_id = aws_instance.this.id
    timestamp   = timestamp()  # Forces execution on every apply
  }

  connection {
    type        = "ssh"
    host        = aws_instance.this.public_ip
    user        = "ec2-user"
    private_key = var.ssh_private_key
    timeout     = "5m"
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Executing remote-exec provisioner...'",
      "${var.airflow_scripts}",
      "sudo su - airflow -c \"set -a; source /etc/airflow/airflow.env; set +a; source ~/venv/bin/activate; airflow dags reserialize\"",
      "b64='${base64encode(local.airflow_conn)}'; set +e; printf %s \"$b64\" | base64 -d | bash -s; rc=$?; if [ $rc -eq 141 ]; then echo 'Ignoring benign SIGPIPE (141)'; exit 0; else exit $rc; fi"
    ]
  }

  depends_on = [aws_instance.this]
}