variable project {
  description = "The name of the project"
  type        = string
}

variable environment {
  description = "The environment for the VPC (e.g., dev, staging, prod)"
  type        = string
}

variable region {
  description = "The AWS region where the VPC will be created"
  type        = string
  default     = "ap-southeast-2"
}