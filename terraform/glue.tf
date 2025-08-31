resource "aws_glue_catalog_database" "raw" {
  name         = var.glue_db_name[0] # raw
  description  = "Glue DB over ${local.raw_uri}"
  location_uri = local.raw_uri
  tags       = {
    Project = "bootcamp",
    Env = "dev"
  }
}

resource "aws_glue_catalog_database" "clean" {
  name         = var.glue_db_name[1] # clean
  description  = "Glue DB over ${local.clean_uri}"
  location_uri = local.clean_uri
  tags       = {
    Project = "bootcamp",
    Env = "dev"
  }
}

resource "aws_s3_object" "clean_directory" {
  bucket  = module.data_bucket.bucket_name
  key     = "clean/"
}

resource "aws_s3_object" "raw_directory" {
  bucket  = module.data_bucket.bucket_name
  key     = "raw/"
}