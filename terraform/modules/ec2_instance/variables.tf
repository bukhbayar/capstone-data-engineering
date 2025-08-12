variable instance_type {
  description = "The type of instance to start"
  type        = string
  default     = "t2.micro"
}

variable subnet_id {
  description = "The ID of the subnet in which to launch the instance"
  type        = string
  default      = ""
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
