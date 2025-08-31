environment   = "dev"
project       = "data-lake"
instance_type = "t3.medium"
bucket_name   = "buku"
aws_region    = "ap-southeast-2"
airflow_admin_user = "buku"
airflow_admin_pass = "buku123123"
dbt_container_image = "324037302945.dkr.ecr.ap-southeast-2.amazonaws.com/dbt:latest"

csv_objects = {
  "customers/customers.csv" = "../datasets/customers.csv",
  "accounts/accounts.csv" = "../datasets/accounts.csv",
  "transactions/transactions.csv" = "../datasets/transactions.csv",
  "time/time.csv" = "../datasets/time.csv"
}
python_objects = {
  "dags/extract.py" = "../scripts/extract.py",
  "dags/extract_dag.py" = "../scripts/extract_dag.py"
}
databases = [
    { name = "airflow_db",   user = "airflow",   password = "airflow" },
    { name = "bootcamp_db",  user = "bootcamp_user", password = "bootcamp_password" },
    { name = "metabase_db",  user = "metabase_user", password = "metabase_password" }
]
ip_addresses = [
    "10.20.1.50",
    "10.20.1.51"
]

glue_db_name = "clean"