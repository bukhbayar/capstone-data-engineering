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

# ---------- customers ----------
resource "aws_glue_catalog_table" "raw_customers" {
  name          = "customers"
  database_name = var.glue_db_name[0]
  table_type    = "EXTERNAL_TABLE"

  parameters = {
    classification        = "parquet"
    EXTERNAL              = "TRUE"
    "parquet.compression" = "SNAPPY"
  }

  partition_keys {
    name = "load_date"
    type = "string"
  }

  storage_descriptor {
    location      = "${local.raw_uri}customers/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"
    number_of_buckets = -1

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
    }

    # ---- columns to match your raw parquet schema ----
    columns {
      name = "customer_code"
      type = "string"
    }

    columns {
      name = "first_name"
      type = "string"
    }
    columns {
      name = "last_name"
      type = "string"
    }
    columns {
      name = "id_number"
      type = "string"
    }
    columns {
      name = "date_of_birth"
      type = "string"
      }
    columns {
      name = "gender"
      type = "string"
      }
    columns {
      name = "email"
      type = "string"
      }
    columns {
      name = "phone_number"
      type = "string"
      }
    columns {
      name = "province"
      type = "string"
      }
    columns {
      name = "city"
      type = "string"
      }
    columns {
      name = "postal_code"
      type = "string"
      }
    columns {
      name = "income_bracket"
      type = "string"
    }
    columns {
      name = "employment_status"
      type = "string"
      }
    columns {
      name = "credit_score"
      type = "string"
      }
    columns {
      name = "primary_bank"
      type = "string"
      }
    columns {
      name = "primary_branch"
      type = "string"
      }
  }
}