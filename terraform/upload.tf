resource "aws_s3_object" "csv" {
  for_each = var.csv_objects

  bucket       = module.data_bucket.bucket_name
  key          = "raw/${each.key}"
  source       = each.value
  content_type = "text/csv"

  # ensure updates when local file changes
  etag = filemd5(each.value)

  server_side_encryption = "AES256" # S3-managed encryption
  tags = {
    uploadedBy  = "terraform"
    project  = var.project
  }
}

resource "aws_s3_object" "python" {
  for_each = var.python_objects

  bucket       = module.code_bucket.bucket_name
  key          = "${each.key}"
  source       = each.value
  content_type = "text/x-python-script"

  # ensure updates when local file changes
  etag = filemd5(each.value)

  server_side_encryption = "AES256" # S3-managed encryption
  tags = {
    uploadedBy  = "terraform"
    project  = var.project
  }
}
