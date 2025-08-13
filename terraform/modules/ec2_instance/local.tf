
locals {
  name = "${var.project}-${var.environment}-etl"

  user_data = <<-EOF
    #!/usr/bin/env bash
    set -euxo pipefail

    dnf -y update
    dnf -y install python3.11 python3.11-pip git

    # Create airflow user + venv
    id -u airflow &>/dev/null || useradd -m -s /bin/bash airflow
    su - airflow -c "python3.11 -m venv ~/venv && source ~/venv/bin/activate && pip install --upgrade pip"
    su - airflow -c "source ~/venv/bin/activate && pip install 'apache-airflow[amazon]==2.9.2'"

    # AIRFLOW_HOME
    echo 'export AIRFLOW_HOME=/home/airflow/airflow' >> /home/airflow/.bashrc
    su - airflow -c "mkdir -p ~/airflow/dags ~/airflow/logs"

    # Minimal config & init
    su - airflow -c "source ~/venv/bin/activate && airflow db init"
    su - airflow -c "source ~/venv/bin/activate && airflow users create --username '${var.airflow_admin_user}' --password '${var.airflow_admin_pass}' --firstname Admin --lastname User --role Admin --email admin@example.com"

    # Simple systemd units
    cat >/etc/systemd/system/airflow-webserver.service <<'UNIT'
    [Unit]
    Description=Airflow Webserver
    After=network.target

    [Service]
    User=airflow
    Environment=PATH=/home/airflow/venv/bin
    Environment=AIRFLOW_HOME=/home/airflow/airflow
    ExecStart=/home/airflow/venv/bin/airflow webserver --port 8080
    Restart=always

    [Install]
    WantedBy=multi-user.target
    UNIT

    cat >/etc/systemd/system/airflow-scheduler.service <<'UNIT'
    [Unit]
    Description=Airflow Scheduler
    After=network.target

    [Service]
    User=airflow
    Environment=PATH=/home/airflow/venv/bin
    Environment=AIRFLOW_HOME=/home/airflow/airflow
    ExecStart=/home/airflow/venv/bin/airflow scheduler
    Restart=always

    [Install]
    WantedBy=multi-user.target
    UNIT

    systemctl daemon-reload
    systemctl enable --now airflow-webserver.service airflow-scheduler.service
  EOF

}