variable project {
  description = "The project name for tagging"
  type        = string
}

variable environment {
  description = "The environment for tagging (e.g., dev, staging, prod)"
  type        = string
}

variable private_subnet_ids {
  description = "List of private subnet IDs for the Batch compute environment"
  type        = list(string)
}

variable vpc_id {
  description = "The ID of the VPC in which to create the security group"
  type        = string
}

variable dbt_container_image {
  description = "The Docker image for the dbt job"
  type        = string
}

variable dbt_vcpu {
  description = "The number of vCPUs to allocate for the dbt job"
  type        = number
  default     = 1
}

variable dbt_memory {
  description = "The amount of memory (in MiB) to allocate for the dbt job"
  type        = number
  default     = 2048
}

variable aws_region {
  description = "The AWS region where resources will be created"
  type        = string
}