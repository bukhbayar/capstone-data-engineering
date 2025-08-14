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
  vpc_id                 = "vpc-0050952f5c44ed5fe"
  private_subnet_ids     = ["subnet-0b03f4786e476b378", "subnet-06736963490685074","subnet-092b7a7588460e249"]
  dbt_container_image    = var.dbt_container_image
  dbt_vcpu               = var.dbt_vcpu
  dbt_memory             = var.dbt_memory
  aws_region             = var.aws_region
}

# module "network" {
#   source      = "./modules/vpc"
#   project     = var.project
#   environment = var.environment
#   region      = var.aws_region
# }

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
