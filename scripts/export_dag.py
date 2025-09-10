from __future__ import annotations
import os, io, tempfile
from datetime import datetime
import boto3
import pandas as pd
import pyarrow as pa
import pyarrow.parquet as pq
from airflow.decorators import dag, task
from airflow.models import Variable
from airflow.providers.postgres.hooks.postgres import PostgresHook
from airflow.operators.python import get_current_context

# --- Config (edit or set as Airflow Variables) ---
POSTGRES_CONN_ID = Variable.get("PG_CONN_ID", default_var="postgres_default")
SCHEMA           = Variable.get("PG_SCHEMA", default_var="public")
TABLES           = Variable.get("PG_TABLES", default_var="customers,accounts,transactions").split(",")
S3_BUCKET        = Variable.get("LAKE_BUCKET", default_var="data-lake-dev-buku")
S3_PREFIX        = Variable.get("LAKE_RAW_PREFIX", default_var="raw")
CHUNK_ROWS       = int(Variable.get("EXPORT_CHUNK_ROWS", default_var="200000"))  # tune if needed

def _export_one_table(table: str, ds: str):
    """Read table from Postgres in chunks and write Parquet parts to s3://bucket/prefix/<table>/load_date=YYYY-MM-DD/"""
    hook = PostgresHook(postgres_conn_id=POSTGRES_CONN_ID)
    engine = hook.get_sqlalchemy_engine()
    s3 = boto3.client("s3")

    target_prefix = f"{S3_PREFIX}/{table}/load_date={ds}/"
    sql = f'SELECT * FROM "{SCHEMA}"."{table}"'  # quoted to be safe

    part = 0
    with engine.connect() as conn:
        for df in pd.read_sql(sql, conn, chunksize=CHUNK_ROWS):
            if df.empty:
                continue

            if table == "customers":
                df['id_number'] = df['id_number'].astype(str)
                df['phone_number'] = df['phone_number'].astype(str)
                df['postal_code'] = df['postal_code'].astype(str)
                df['credit_score'] = df['credit_score'].astype(str)

                schema_pa = pa.schema([
                    pa.field('customer_code', pa.string()),
                    pa.field('first_name', pa.string()),
                    pa.field('last_name', pa.string()),
                    pa.field('id_number', pa.string()),
                    pa.field('date_of_birth', pa.string()),
                    pa.field('gender', pa.string()),
                    pa.field('email', pa.string()),
                    pa.field('phone_number', pa.string()),
                    pa.field('province', pa.string()),
                    pa.field('city', pa.string()),
                    pa.field('postal_code', pa.string()),
                    pa.field('income_bracket', pa.string()),
                    pa.field('employment_status', pa.string()),
                    pa.field('credit_score', pa.string()),
                    pa.field('primary_bank', pa.string()),
                    pa.field('primary_branch', pa.string())
                ])

                table_pa = pa.Table.from_pandas(df, preserve_index=False, schema=schema_pa)
            elif table == "accounts":
                df['bank_code'] = df['bank_code'].astype(str)
                df['balance'] = df['balance'].astype(str)
                df['interest_rate'] = df['interest_rate'].astype(str)
            else:
                df['amount'] = df['amount'].astype(str)

            table_pa = pa.Table.from_pandas(df, preserve_index=False)

            # write to memory (fast) and upload
            buf = io.BytesIO()
            pq.write_table(table_pa, buf, compression="snappy")
            buf.seek(0)

            key = f"{target_prefix}part-{part:05d}.snappy.parquet"
            s3.put_object(Bucket=S3_BUCKET, Key=key, Body=buf.getvalue())
            part += 1

    # if nothing was written, still create a _SUCCESS marker so downstream is predictable
    if part == 0:
        s3.put_object(Bucket=S3_BUCKET, Key=f"{target_prefix}_EMPTY")
    else:
        s3.put_object(Bucket=S3_BUCKET, Key=f"{target_prefix}_SUCCESS")

@dag(
    dag_id="export_postgres_to_s3_raw_parquet",
    schedule="@daily",
    start_date=datetime(2025, 1, 1),
    catchup=False,
    default_args={"owner": "data-eng", "retries": 1},
    tags=["export","postgres","s3","parquet","lake"],
)

def export_postgres_to_s3_raw_parquet():
    @task
    def export_table(table: str):
        ds = get_current_context()["ds"]
        _export_one_table(table, ds)

    export_table.expand(table=TABLES)

export_postgres_to_s3_raw_parquet()