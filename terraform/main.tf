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
# create_database = true => 1
# create_database = false => 0
# 1 create database
# 0 destroy
# example: if 1=1 ? equal : not equal
module "ec2-datatabase" {
  count           = var.create_database ? 1 : 0
  source          = "./modules/ec2_instance"
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

  private_ip      = var.ip_addresses[1]

  user_data = <<-EOF
    #!/usr/bin/env bash
    set -euxo pipefail

    dnf -y update
    dnf -y install python3.11 python3.11-pip git

    # Create airflow user + venv
    id -u airflow &>/dev/null || useradd -m -s /bin/bash airflow
    su - airflow -c "python3.11 -m venv ~/venv && source ~/venv/bin/activate && pip install --upgrade pip"

    # First install SQLAlchemy and database dependencies
    su - airflow -c source ~/venv/bin/activate && pip install \
      'SQLAlchemy>=1.4.0,<2.0.0' \
      'psycopg2-binary>=2.9.0' \
      'alembic>=1.6.3'

    # Install Airflow and dependencies
    su - airflow -c source ~/venv/bin/activate && pip install \
        'apache-airflow==2.9.2' \
        'apache-airflow[amazon,postgres,celery,redis]==2.9.2' \
        'apache-airflow-providers-dbt-cloud' \
        'apache-airflow-providers-common-sql' \
        'apache-airflow-providers-standard' \
         --constraint 'https://raw.githubusercontent.com/apache/airflow/constraints-2.9.2/constraints-3.11.txt'

    # Redis
    dnf -y install redis6
    systemctl enable --now redis6

    # AIRFLOW_HOME
    echo 'export AIRFLOW_HOME=/home/airflow/airflow' >> /home/airflow/.bashrc
    su - airflow -c "mkdir -p ~/airflow/dags ~/airflow/logs"

    # Generate a Fernet key (used to encrypt connections/variables)
    FERNET_KEY=$(su - airflow -c "source ~/venv/bin/activate && python - <<'PY'
    from cryptography.fernet import Fernet
    print(Fernet.generate_key().decode())
    PY
    ")

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
  source                 = "./modules/batch"
  project                = var.project
  environment            = var.environment
  vpc_id                 = module.network.vpc_id
  private_subnet_ids     = module.network.public_subnet_ids
  dbt_container_image    = var.dbt_container_image
  dbt_vcpu               = var.dbt_vcpu
  dbt_memory             = var.dbt_memory
  aws_region             = var.aws_region
}

module "network" {
  source      = "./modules/vpc"
  project     = var.project
  environment = var.environment
  region      = var.aws_region
}

# module "ec2_instance" {
#   source  = "git::https://github.com/terraform-aws-modules/terraform-aws-ec2-instance.git?ref=v5.8.0"

#   name = "single-instance"

#   instance_type = "t2.micro"
#   key_name      = "demo-key"
#   monitoring    = true
#   subnet_id     = "subnet-0b03f4786e476b378"

#   tags = {
#     Terraform   = "true"
#     Environment = "dev"
#   }
# }
