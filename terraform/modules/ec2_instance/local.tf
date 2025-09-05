locals {
  name      = "${var.project}-${var.environment}-etl"
  user_data = var.user_data

  airflow_conn = <<-EOF
    #!/usr/bin/env bash
    set -euo pipefail

    POSTGRES_HOST="10.20.1.50"
    POSTGRES_DB="bootcamp_db"
    POSTGRES_USER="bootcamp_user"
    POSTGRES_PASSWORD="bootcamp_password"
    POSTGRES_PORT="5432"

    # Use $${} so Terraform doesn't interpolate; bash will.
    PG_URI="postgresql+psycopg2://$${POSTGRES_USER}:$${POSTGRES_PASSWORD}@$${POSTGRES_HOST}:$${POSTGRES_PORT}/$${POSTGRES_DB}"

    # Shell snippet to run Airflow in the right env/venv
    AIRFLOW_CMD="set -a; [ -f /etc/airflow/airflow.env ] && source /etc/airflow/airflow.env; set +a; source ~/venv/bin/activate; airflow"

    # Check if the connection exists
    if sudo -n -iu airflow bash -lc "$AIRFLOW_CMD connections get postgres_default >/dev/null 2>&1"; then
      echo "[conn:postgres_default] exists"
    fi

    echo "[conn:postgres_default] creating"
    yes | sudo -n -iu airflow bash -lc "$AIRFLOW_CMD connections add postgres_default --conn-uri \"$PG_URI\" --conn-description 'Postgres on EC2 - bootcamp_db'"

    echo "Airflow connections ensured."
  EOF
}