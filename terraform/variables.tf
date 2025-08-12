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