from datetime import datetime
from airflow import DAG
from airflow.models import Variable
from airflow.utils.trigger_rule import TriggerRule
from airflow.providers.amazon.aws.operators.batch import BatchSubmitJobOperator

JOB_QUEUE       = Variable.get("BATCH_JOB_QUEUE", default_var="data-lake-dev-batch-queue")
JOB_DEFINITION  = Variable.get("BATCH_JOB_DEFINITION", default_var="data-lake-dev-batch-dbt")
DEFAULT_TARGET  = Variable.get("DBT_TARGET", default_var="dev")

with DAG(
    dag_id="dbt_batch_runner",
    start_date=datetime(2025, 1, 1),
    schedule=None,   # trigger manually or via another DAG
    catchup=False,
    params={
        # default cmd; can be overridden in Trigger DAG -> JSON config
        "dbt_cmd": f"run -t {DEFAULT_TARGET}",
    },
    tags=["dbt","batch"],
) as dag:

    run_dbt = BatchSubmitJobOperator(
        task_id="submit_dbt_job",
        job_name="dbt-{{ ds_nodash }}",
        job_queue=JOB_QUEUE,
        job_definition=JOB_DEFINITION,
        # Pass the command through the *parameters* map
        parameters={
            # Prefer run config value if provided, otherwise DAG param default
            "cmd": "{{ dag_run.conf.get('dbt_cmd', params.dbt_cmd) }}"
        },
        # Optionally add/override environment variables
        overrides={
            "environment": [
                {"name": "DBT_TARGET", "value": f"{DEFAULT_TARGET}"},
                # add more if your image expects them
            ]
        },
        wait_for_completion=True,   # or False if you want fire-and-forget
        max_retries=0,
    )