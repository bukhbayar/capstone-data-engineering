
resource "aws_s3_bucket" "this" {
  bucket = local.name
  tags   = {
    Project     = var.project,
    Environment = var.environment
  }
}
