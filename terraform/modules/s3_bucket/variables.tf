variable project {
  description = "The project name for tagging"
  type        = string
}

variable environment {
  description = "The environment for tagging (e.g., dev, staging, prod)"
  type        = string
}

variable bucket_name {
  description = "Bucket name"
  type        = string
}
