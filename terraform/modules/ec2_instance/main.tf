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
  # Add triggers to ensure the resource runs on every apply
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
      <<-EOF
        #!/usr/bin/env bash
        set -euo pipefail

        AIRFLOW_BIN="su - airflow -c "set -a; source /etc/airflow/airflow.env; set +a; source ~/venv/bin/activate; airflow"

        # --------- Inputs (edit defaults or export as env vars) ----------
        POSTGRES_HOST="10.20.1.50"
        POSTGRES_DB="bootcamp_db"
        POSTGRES_USER="bootcamp_user"
        POSTGRES_PASSWORD="bootcamp_password"
        POSTGRES_PORT="5432"

        # --------- Helpers ----------
        upsert_conn() {
          local id="$1"; shift
          if $AIRFLOW_BIN connections get "$id" >/dev/null 2>&1; then
            echo "[conn:$id] exists → overwriting"
            $AIRFLOW_BIN connections add "$id" --overwrite "$@"
          else
            echo "[conn:$id] creating"
            $AIRFLOW_BIN connections add "$id" "$@"
          fi
        }

        # --------- Postgres connection ---------
        PG_URI="postgresql+psycopg2://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:${POSTGRES_PORT}/${POSTGRES_DB}"
        upsert_conn postgres_default \
          --conn-uri "$PG_URI" \
          --conn-description "Postgres on EC2 (bootcamp_db)"

        echo "Airflow connections ensured."
      EOF
    ]
  }

  depends_on = [aws_instance.this]
}