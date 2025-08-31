from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.amazon.aws.hooks.s3 import S3Hook
from airflow.providers.postgres.hooks.postgres import PostgresHook
from datetime import datetime, timedelta
import pandas as pd
import io

default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'start_date': datetime(2025, 1, 1),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5)
}

# Dictionary mapping S3 keys to table names
S3_KEYS = {
    'customers': 'landing/customers/customers.csv',
    'accounts': 'landing/accounts/accounts.csv',
    'transactions': 'landing/transactions/transactions.csv'
}

def load_csv_to_postgres(table_name: str, s3_key: str):
    """Load CSV from S3 and insert into PostgreSQL"""
    # Get S3 object
    s3_hook = S3Hook(aws_conn_id='aws_default')
    bucket_name = 'data-lake-dev-buku'

    # Read CSV file from S3
    s3_object = s3_hook.get_key(key=s3_key, bucket_name=bucket_name)
    csv_content = s3_object.get()['Body'].read().decode('utf-8')
    df = pd.read_csv(io.StringIO(csv_content))

    # Load to PostgreSQL
    postgres_hook = PostgresHook(postgres_conn_id='postgres_default')
    engine = postgres_hook.get_sqlalchemy_engine()

    print(f"Inserting {len(df)} records into {table_name}...")
    df.to_sql(
        table_name,
        engine,
        if_exists='append',
        index=False
    )
    print(f"{table_name} inserted successfully.")

with DAG(
    'load_csv_to_postgres',
    default_args=default_args,
    description='Load CSV files from S3 to PostgreSQL',
    schedule_interval='@daily',
    catchup=False
) as dag:

    # Create a task for each table
    tasks = []
    for table_name, s3_key in S3_KEYS.items():
        task = PythonOperator(
            task_id=f'load_{table_name}',
            python_callable=load_csv_to_postgres,
            op_kwargs={
                'table_name': table_name,
                's3_key': s3_key
            }
        )
        tasks.append(task)

    # Set task dependencies (run in sequence)
    for i in range(len(tasks) - 1):
        tasks[i] >> tasks[i + 1]