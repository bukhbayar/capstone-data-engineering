# dags/export_pg_to_s3_parquet.py
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
    schedule="@daily",                 # or None if you only trigger manually
    start_date=datetime(2025, 1, 1),   # pick an appropriate start
    catchup=False,
    default_args={"owner": "data-eng", "retries": 1},
    tags=["export","postgres","s3","parquet","lake"],
)
def export_postgres_to_s3_raw_parquet():
    @task
    def export_table(table: str, ds: str = "{{ ds }}"):
        _export_one_table(table, ds)

    # dynamic mapping over the tables
    export_table.expand(table=TABLES)

export_postgres_to_s3_raw_parquet()