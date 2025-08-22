variable instance_type {
  description = "The type of instance to start"
  type        = string
}

variable subnet_id {
  description = "The ID of the subnet in which to launch the instance"
  type        = string
}

variable project {
  description = "The project name for tagging"
  type        = string
}

variable environment {
  description = "The environment for tagging (e.g., dev, staging, prod)"
  type        = string
}

variable vpc_id {
  description = "The ID of the VPC in which to create the security group"
  type        = string
  default     = ""
}

variable airflow_logs_bucket {
  description = "The S3 bucket for Airflow logs"
  type        = string
  default     = ""
}

variable airflow_admin_user {
  description = "The Airflow admin user name"
  type        = string
  default     = ""
}

variable airflow_admin_pass {
  description = "The Airflow admin user password"
  type        = string
  default     = ""
}

variable security_group_ids {
  description = "Additional security group IDs to associate with the instance"
  type        = list(string)
}

variable user_data {
  description = "User data script to run on instance launch"
  type        = string
}

variable role_name {
  description = "The name of the IAM role to create for the instance"
  type        = string
}

variable private_ip {
  description = "The private IP address to assign to the instance"
  type        = string
}