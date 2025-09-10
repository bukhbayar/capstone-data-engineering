resource "aws_glue_catalog_database" "raw" {
  name         = var.glue_db_name[0] # raw
  description  = "Glue DB over ${local.raw_uri}"
  location_uri = local.raw_uri
  tags       = {
    Project = "bootcamp",
    Env = "dev"
  }
}

resource "aws_s3_object" "raw_directory" {
  bucket  = module.data_bucket.bucket_name
  key     = "raw/"
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

resource "aws_glue_catalog_database" "warehouse" {
  name         = var.glue_db_name[2] # warehouse
  description  = "Glue DB over ${local.warehouse_uri}"
  location_uri = local.warehouse_uri
  tags       = {
    Project = "bootcamp",
    Env = "dev"
  }
}

resource "aws_s3_object" "warehouse_directory" {
  bucket  = module.data_bucket.bucket_name
  key     = "warehouse/"
}

resource "aws_glue_catalog_database" "mart" {
  name         = var.glue_db_name[3] # mart
  description  = "Glue DB over ${local.mart_uri}"
  location_uri = local.mart_uri
  tags       = {
    Project = "bootcamp",
    Env = "dev"
  }
}

resource "aws_s3_object" "mart_directory" {
  bucket  = module.data_bucket.bucket_name
  key     = "mart/"
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

# ---------- accounts ----------
resource "aws_glue_catalog_table" "raw_accounts" {
  name          = "accounts"
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
    location      = "${local.raw_uri}accounts/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"
    number_of_buckets = -1

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
    }

    # ---- columns to match your raw parquet schema ----
    columns {
      name = "account_id"
      type = "string"
    }

    columns {
      name = "customer_id"
      type = "string"
    }
    columns {
      name = "bank_name"
      type = "string"
    }
    columns {
      name = "branch_name"
      type = "string"
    }
    columns {
      name = "bank_code"
      type = "string"
      }
    columns {
      name = "swift_code"
      type = "string"
      }
    columns {
      name = "account_type"
      type = "string"
      }
    columns {
      name = "opening_date"
      type = "string"
      }
    columns {
      name = "balance"
      type = "string"
      }
    columns {
      name = "status"
      type = "string"
      }
    columns {
      name = "interest_rate"
      type = "string"
      }
    columns {
      name = "currency"
      type = "string"
    }
  }
}

# ---------- transactions ----------
resource "aws_glue_catalog_table" "raw_transactions" {
  name          = "transactions"
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
    location      = "${local.raw_uri}transactions/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"
    number_of_buckets = -1

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
    }

    # ---- columns to match your raw parquet schema ----
    columns {
      name = "transaction_id"
      type = "string"
    }

    columns {
      name = "account_id"
      type = "string"
    }
    columns {
      name = "bank_name"
      type = "string"
    }
    columns {
      name = "transaction_type"
      type = "string"
    }
    columns {
      name = "amount"
      type = "string"
      }
    columns {
      name = "currency"
      type = "string"
      }
    columns {
      name = "transaction_date"
      type = "string"
      }
    columns {
      name = "status"
      type = "string"
      }
    columns {
      name = "description"
      type = "string"
      }
    columns {
      name = "merchant_name"
      type = "string"
      }
    columns {
      name = "reference"
      type = "string"
      }
    columns {
      name = "transaction_category"
      type = "string"
    }
  }
}