locals {
  name      = "${var.project}-${var.environment}-etl"
  user_data = var.user_data

  airflow_conn = <<-EOF
    #!/usr/bin/env bash
    set -euo pipefail

    # Compose the Airflow CLI inside the same env/venv the services use
    AIRFLOW_SH='set -a; source /etc/airflow/airflow.env; set +a; source ~/venv/bin/activate; airflow'

    POSTGRES_HOST="10.20.1.50"
    POSTGRES_DB="bootcamp_db"
    POSTGRES_USER="bootcamp_user"
    POSTGRES_PASSWORD="bootcamp_password"
    POSTGRES_PORT="5432"

    # Use $${} so Terraform doesn't interpolate; bash will.
    PG_URI="postgresql+psycopg2://$${POSTGRES_USER}:$${POSTGRES_PASSWORD}@$${POSTGRES_HOST}:$${POSTGRES_PORT}/$${POSTGRES_DB}"

    # Idempotent upsert of the connection
    if su - airflow -c "bash -lc '$AIRFLOW_SH connections get postgres_default >/dev/null 2>&1'"; then
      echo "[conn:postgres_default] exists → overwriting"
      su - airflow -c "bash -lc '$AIRFLOW_SH connections add postgres_default --overwrite --conn-uri \"$PG_URI\" --conn-description \"Postgres on EC2 - bootcamp_db\"'"
    else
      echo "[conn:postgres_default] creating"
      su - airflow -c "bash -lc '$AIRFLOW_SH connections add postgres_default --conn-uri \"$PG_URI\" --conn-description \"Postgres on EC2 - bootcamp_db\"'"
    fi

    echo "Airflow connections ensured."
  EOF
}