
resource "aws_s3_bucket" "this" {
  bucket = var.bucket_name
  tags   = {
    Project     = var.project,
    Environment = var.environment
  }
}
