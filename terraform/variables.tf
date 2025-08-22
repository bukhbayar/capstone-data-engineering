variable project {
  description = "The project name for tagging"
  type        = string
  default     = "bootcamp"
}

variable environment {
  description = "The environment for tagging (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable instance_type {
  description = "The type of EC2 instance to create"
  type        = string
  default     = "t2.micro"
}

variable bucket_name {
  type        = string
  description = "bucket name"
}

variable aws_region {
  type        = string
  description = "AWS region to deploy resources"
}

variable airflow_admin_user {
  description = "The Airflow admin user name"
  type        = string
}

variable airflow_admin_pass {
  description = "The Airflow admin user password"
  type        = string
}

variable dbt_container_image {
  description = "The Docker image for the dbt container"
  type        = string
}

variable dbt_vcpu {
  description = "The number of vCPUs for the dbt container"
  type        = number
  default     = 2
}

variable dbt_memory {
  description = "The amount of memory (in MiB) for the dbt container"
  type        = number
  default     = 4096
}

variable "csv_objects" {
  type = map(string)
  description = "e.g., { 'customer.csv' = '/abs/path/customer.csv', ... }"
}

variable "python_objects" {
  type = map(string)
  description = "e.g., { 'customer.csv' = '/abs/path/customer.csv', ... }"
}

variable "databases" {
  description = "List of DBs to create with owners/passwords"
  type = list(object({
    name     : string
    user     : string
    password : string
  }))
}

variable "ip_addresses" {
  description = "List of IP addresses to allow access to the Airflow web server"
  type        = list(string)
}

variable "create_database" {
  description = "Flag to create a database"
  type        = bool
}

variable "create_airflow" {
  description = "Flag to create a airflow"
  type        = bool
}