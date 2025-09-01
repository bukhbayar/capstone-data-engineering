terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-2"
}

module "ec2-datatabase" {
  count           = var.create_database ? 1 : 0
  source          = "./modules/ec2_instance"
  depends_on      = [
                      aws_s3_object.csv,
                      aws_s3_object.python,
                      module.network
                    ]
  project         = var.project
  environment     = var.environment
  instance_type   = var.instance_type
  role_name       = "ec2-database"
  subnet_id       = module.network.public_subnet_ids[0]
  vpc_id          = module.network.vpc_id
  security_group_ids = [aws_security_group.sg_postgres.id, aws_security_group.sg.id]

  airflow_logs_bucket = ""
  airflow_admin_user = ""
  airflow_admin_pass = ""
  airflow_dags_bucket = ""
  airflow_scripts  = "echo 'No scripts to run'"
  enable_airflow_seed = false

  ssh_private_key = var.ssh_private_key

  private_ip      = var.ip_addresses[0]

  user_data = <<-EOF
    #!/usr/bin/env bash
    set -euxo pipefail

    dnf -y update
    dnf -y install postgresql15 postgresql15-server

    # Initialize data directory
    /usr/bin/postgresql-setup --initdb

    # Listen on all interfaces
    sed -i "s/^#listen_addresses = .*/listen_addresses = '*'/g" /var/lib/pgsql/data/postgresql.conf

    # Allow connections from anywhere (not recommended for production)
    echo "host    all             all              0.0.0.0/0              scram-sha-256" >> /var/lib/pgsql/data/pg_hba.conf

    # Start & enable service
    systemctl enable --now postgresql

    # Create DB and user (practice only; use Secrets Manager & parameterized scripts in prod)
    sudo -u postgres psql -v ON_ERROR_STOP=1 -d postgres <<'SQL'
    ${local.db_bootstrap_sql}
    SQL
  EOF
}

module "ec2-airflow" {
  count           = var.create_airflow ? 1 : 0
  source          = "./modules/ec2_instance"
  depends_on      = [
                      aws_s3_object.csv,
                      aws_s3_object.python,
                      module.ec2-datatabase,
                      module.network
                    ]
  project         = var.project
  environment     = var.environment
  instance_type   = var.instance_type
  role_name       = "ec2-airflow"
  subnet_id       = module.network.public_subnet_ids[0]
  vpc_id          = module.network.vpc_id
  security_group_ids = [aws_security_group.sg_airflow.id, aws_security_group.sg.id]
  airflow_logs_bucket = module.data_bucket.bucket_name
  airflow_admin_user = var.airflow_admin_user
  airflow_admin_pass = var.airflow_admin_pass
  airflow_dags_bucket = module.code_bucket.bucket_name
  airflow_scripts  = "sudo -u airflow aws s3 sync s3://${module.code_bucket.bucket_name}/dags/ /home/airflow/airflow/dags --delete"
  enable_airflow_seed = true

  ssh_private_key = var.ssh_private_key

  private_ip      = var.ip_addresses[1]

  user_data = <<-EOF
    #!/usr/bin/env bash
    set -euxo pipefail

    dnf -y update
    dnf -y install python3.11 python3.11-pip git

    # Create airflow user + venv
    id -u airflow &>/dev/null || useradd -m -s /bin/bash airflow
    su - airflow -c "python3.11 -m venv ~/venv && source ~/venv/bin/activate && pip install --upgrade pip"

    # First install base dependencies including cryptography
    su - airflow -c "source ~/venv/bin/activate && pip install \
      'cryptography' \
      'SQLAlchemy>=1.4.0,<2.0.0' \
      'psycopg2-binary>=2.9.0' \
      'pyarrow>=21.0.0' \
      'apache-airflow-providers-dbt-cloud>=3.0.0' \
      'apache-airflow-providers-common-sql>=1.10.0' \
      'apache-airflow-providers-standard>=1.0.0' \
      'apache-airflow-providers-amazon>=8.0.0,<9.0.0' \
      'apache-airflow-providers-postgres>=5.10.0' \
      'pandas' \
      'alembic>=1.6.3'"

    # Install Airflow and dependencies
    su - airflow -c "source ~/venv/bin/activate && pip install \
        'apache-airflow==2.9.2' \
        'apache-airflow[amazon,postgres,celery,redis]==2.9.2' \
         --constraint 'https://raw.githubusercontent.com/apache/airflow/constraints-2.9.2/constraints-3.11.txt'"

    # Redis
    dnf -y install redis6
    systemctl enable --now redis6

    # AIRFLOW_HOME
    echo 'export AIRFLOW_HOME=/home/airflow/airflow' >> /home/airflow/.bashrc
    su - airflow -c "mkdir -p ~/airflow/dags ~/airflow/logs"

    # Generate a Fernet key (used to encrypt connections/variables)
    FERNET_KEY=$(su - airflow -c "source ~/venv/bin/activate && python -c 'from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())'")

    # Write environment file consumed by systemd units and CLI
    install -d -m 0755 /etc/airflow
    cat >/etc/airflow/airflow.env <<ENV
    AIRFLOW_HOME=/home/airflow/airflow
    AIRFLOW__CORE__EXECUTOR=CeleryExecutor
    AIRFLOW__CORE__LOAD_EXAMPLES=False
    AIRFLOW__CORE__FERNET_KEY=$${FERNET_KEY}
    AIRFLOW__WEBSERVER__SECRET_KEY=$${FERNET_KEY}
    AIRFLOW__CORE__DAGS_ARE_PAUSED_AT_CREATION=True
    AIRFLOW__SCHEDULER__ENABLE_HEALTH_CHECK=True
    AIRFLOW__API__AUTH_BACKENDS=airflow.api.auth.backend.basic_auth,airflow.api.auth.backend.session
    AIRFLOW__DATABASE__SQL_ALCHEMY_CONN=postgresql+psycopg2://airflow:airflow@${var.ip_addresses[0]}:5432/airflow_db
    AIRFLOW__CELERY__RESULT_BACKEND=db+postgresql://airflow:airflow@${var.ip_addresses[0]}:5432/airflow_db
    AIRFLOW__CELERY__BROKER_URL=redis://localhost:6379/0

    ENV
    chmod 0640 /etc/airflow/airflow.env
    chgrp airflow /etc/airflow/airflow.env

    # Initialize the Airflow DB on Postgres (env must be loaded for this)
    su - airflow -c "set -a; source /etc/airflow/airflow.env; set +a; source ~/venv/bin/activate; airflow db migrate"

    # Create admin user
    su - airflow -c "set -a; source /etc/airflow/airflow.env; set +a; source ~/venv/bin/activate; airflow users create --username '${var.airflow_admin_user}' --password '${var.airflow_admin_pass}' --firstname Admin --lastname User --role Admin --email admin@example.com"

    # Updated systemd units with environment file and dependencies
    cat >/etc/systemd/system/airflow-webserver.service <<'UNIT'
    [Unit]
    Description=Airflow Webserver
    After=network.target postgresql.service redis6.service
    Wants=postgresql.service redis6.service

    [Service]
    User=airflow
    EnvironmentFile=/etc/airflow/airflow.env
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
    After=network.target postgresql.service redis6.service airflow-webserver.service
    Wants=postgresql.service redis6.service

    [Service]
    User=airflow
    EnvironmentFile=/etc/airflow/airflow.env
    Environment=PATH=/home/airflow/venv/bin
    Environment=AIRFLOW_HOME=/home/airflow/airflow
    ExecStart=/home/airflow/venv/bin/airflow scheduler
    Restart=always

    [Install]
    WantedBy=multi-user.target
    UNIT

    # Add Celery worker service
    cat >/etc/systemd/system/airflow-worker.service <<'UNIT'
    [Unit]
    Description=Airflow Celery Worker
    After=network.target postgresql.service redis6.service airflow-webserver.service
    Wants=postgresql.service redis6.service

    [Service]
    User=airflow
    EnvironmentFile=/etc/airflow/airflow.env
    Environment=PATH=/home/airflow/venv/bin
    Environment=AIRFLOW_HOME=/home/airflow/airflow
    ExecStart=/home/airflow/venv/bin/airflow celery worker
    Restart=always

    [Install]
    WantedBy=multi-user.target
    UNIT

    # Wait for database to be ready
    sleep 10

    systemctl daemon-reload
    systemctl enable airflow-webserver airflow-scheduler airflow-worker
    systemctl start airflow-webserver
    sleep 5
    systemctl start airflow-scheduler
    sleep 5
    systemctl start airflow-worker

    sudo -u airflow aws s3 sync s3://${module.code_bucket.bucket_name}/dags/ /home/airflow/airflow/dags --delete

  EOF
}

module "code_bucket" {
  source      = "./modules/s3_bucket"
  project     = var.project
  environment = var.environment
  bucket_name = "code-${var.environment}-buku"
}

module "data_bucket" {
  source      = "./modules/s3_bucket"
  project     = var.project
  environment = var.environment
  bucket_name = "${var.project}-${var.environment}-buku"
}

module "batch" {
  source                  = "./modules/batch"
  project                 = var.project
  environment             = var.environment
  vpc_id                  = module.network.vpc_id
  private_subnet_ids      = module.network.private_subnet_ids
  dbt_container_image     = var.dbt_container_image
  dbt_vcpu                = var.dbt_vcpu
  dbt_memory              = var.dbt_memory
  aws_region              = var.aws_region
  private_route_table_ids = module.network.private_route_table_ids
  depends_on              = [module.network]
}

module "network" {
  source      = "./modules/vpc"
  project     = var.project
  environment = var.environment
  region      = var.aws_region
}
