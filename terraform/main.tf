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

# module "ec2-datatabase" {
#   source          = "./modules/ec2_instance"
#   project         = var.project
#   environment     = var.environment
#   instance_type   = var.instance_type
#   subnet_id       = module.network.private_subnet_ids[0]
#   vpc_id          = module.network.vpc_id
#   security_group_ids = [aws_security_group.sg_postgres.id]
#   airflow_logs_bucket = ""
#   airflow_admin_user = ""
#   airflow_admin_pass = ""
#   user_data = <<-EOF
#     #!/usr/bin/env bash
#     set -euxo pipefail

#     dnf -y update
#     dnf -y install postgresql15 postgresql15-server

#     # Initialize data directory
#     /usr/bin/postgresql-setup --initdb

#     # Listen on all interfaces
#     sed -i "s/^#listen_addresses = .*/listen_addresses = '*'/g" /var/lib/pgsql/data/postgresql.conf

#     # Start & enable service
#     systemctl enable --now postgresql

#     # Create DB and user (practice only; use Secrets Manager & parameterized scripts in prod)
#     sudo -u postgres psql -v ON_ERROR_STOP=1 -c "CREATE DATABASE ${var.db_name};"
#     sudo -u postgres psql -v ON_ERROR_STOP=1 -c "DO \$$ BEGIN IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${var.db_user}') THEN CREATE ROLE ${var.db_user} LOGIN PASSWORD '${var.db_password}'; END IF; END \$$;"
#     sudo -u postgres psql -v ON_ERROR_STOP=1 -c "GRANT ALL PRIVILEGES ON DATABASE ${var.db_name} TO ${var.db_user};"
#   EOF
# }

# module "ec2-instance" {
#   source          = "./modules/ec2_instance"
#   project         = var.project
#   environment     = var.environment
#   instance_type   = var.instance_type
#   subnet_id       = "subnet-0b03f4786e476b378"
#   vpc_id          = "vpc-0050952f5c44ed5fe"
#   airflow_logs_bucket = module.data_bucket.bucket_name
#   airflow_admin_user = var.airflow_admin_user
#   airflow_admin_pass = var.airflow_admin_pass
#   user_data = <<-EOF
#   #!/usr/bin/env bash
#   set -euxo pipefail

#   dnf -y update
#   dnf -y install python3.11 python3.11-pip git

#   # Create airflow user + venv
#   id -u airflow &>/dev/null || useradd -m -s /bin/bash airflow
#   su - airflow -c "python3.11 -m venv ~/venv && source ~/venv/bin/activate && pip install --upgrade pip"
#   su - airflow -c "source ~/venv/bin/activate && pip install 'apache-airflow[amazon]==2.9.2'"

#   # AIRFLOW_HOME
#   echo 'export AIRFLOW_HOME=/home/airflow/airflow' >> /home/airflow/.bashrc
#   su - airflow -c "mkdir -p ~/airflow/dags ~/airflow/logs"

#   # Minimal config & init
#   su - airflow -c "source ~/venv/bin/activate && airflow db init"
#   su - airflow -c "source ~/venv/bin/activate && airflow users create --username '${var.airflow_admin_user}' --password '${var.airflow_admin_pass}' --firstname Admin --lastname User --role Admin --email admin@example.com"

#   # Simple systemd units
#   cat >/etc/systemd/system/airflow-webserver.service <<'UNIT'
#   [Unit]
#   Description=Airflow Webserver
#   After=network.target

#   [Service]
#   User=airflow
#   Environment=PATH=/home/airflow/venv/bin
#   Environment=AIRFLOW_HOME=/home/airflow/airflow
#   ExecStart=/home/airflow/venv/bin/airflow webserver --port 8080
#   Restart=always

#   [Install]
#   WantedBy=multi-user.target
#   UNIT

#   cat >/etc/systemd/system/airflow-scheduler.service <<'UNIT'
#   [Unit]
#   Description=Airflow Scheduler
#   After=network.target

#   [Service]
#   User=airflow
#   Environment=PATH=/home/airflow/venv/bin
#   Environment=AIRFLOW_HOME=/home/airflow/airflow
#   ExecStart=/home/airflow/venv/bin/airflow scheduler
#   Restart=always

#   [Install]
#   WantedBy=multi-user.target
#   UNIT

#   systemctl daemon-reload
#   systemctl enable --now airflow-webserver.service airflow-scheduler.service
# EOF

# }

module "data_bucket" {
  source      = "./modules/s3_bucket"
  project     = var.project
  environment = var.environment
  bucket_name = var.bucket_name
}

module "batch" {
  source                 = "./modules/batch"
  project                = var.project
  environment            = var.environment
  vpc_id                 = module.network.vpc_id   # "vpc-0050952f5c44ed5fe"
  private_subnet_ids     = module.network.public_subnet_ids  # ["subnet-0b03f4786e476b378", "subnet-06736963490685074","subnet-092b7a7588460e249"]
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
