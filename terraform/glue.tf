resource "aws_glue_catalog_database" "clean" {
  name         = var.glue_db_name
  description  = "Glue DB over ${local.clean_uri}"
  location_uri = local.clean_uri
  tags       = {
    Project = "bootcamp",
    Env = "dev"
  }
}

resource "aws_s3_object" "clean_directory" {
  bucket  = mobule.data_bucket.bucket_name
  key     = "/clean"
  content = ""
}