from datetime import datetime
from airflow import DAG
from airflow.models import Variable

from airflow.providers.amazon.aws.operators.batch import BatchOperator
from airflow.providers.amazon.aws.sensors.batch import BatchSensor

AWS_CONN_ID    = Variable.get("AWS_CONN_ID", default_var="aws_default")
AWS_REGION     = Variable.get("AWS_REGION",   default_var="ap-southeast-2")
JOB_QUEUE      = Variable.get("BATCH_JOB_QUEUE",      default_var="data-lake-dev-batch-queue")
JOB_DEFINITION = Variable.get("BATCH_JOB_DEFINITION", default_var="data-lake-dev-batch-dbt")
DEFAULT_TARGET = Variable.get("DBT_TARGET",           default_var="dev")

with DAG(
    dag_id="dbt_batch_runner",
    start_date=datetime(2025, 1, 1),
    schedule=None,
    catchup=False,
    params={"dbt_cmd": f"dbt run -t {DEFAULT_TARGET}"},
    tags=["dbt", "batch"],
) as dag:

    # Submit the job
    submit = BatchOperator(
        task_id="submit_dbt_job",
        job_name="dbt-{{ ts_nodash }}",
        job_queue=JOB_QUEUE,
        job_definition=JOB_DEFINITION,

        # If your Job Definition uses command: ["bash","-lc","Ref::cmd"]
        parameters={
            "cmd": "{{ dag_run.conf.get('dbt_cmd', params.dbt_cmd) }}"
        },

        # If your Job Definition does NOT use parameters/Ref::cmd, instead use this:
        # overrides={
        #   "command": ["bash","-lc","{{ dag_run.conf.get('dbt_cmd', params.dbt_cmd) }}"],
        #   "environment": [{"name": "DBT_TARGET", "value": DEFAULT_TARGET}],
        # },

        aws_conn_id=AWS_CONN_ID,
        region_name=AWS_REGION,
    )

    # Wait for completion (BatchOperator in some versions doesn't block)
    wait = BatchSensor(
        task_id="wait_for_dbt",
        job_id=submit.output,            # XCom from submit task
        aws_conn_id=AWS_CONN_ID,
        region_name=AWS_REGION,
        poke_interval=30,                # seconds
        timeout=60 * 60 * 3,             # 3 hours
        mode="poke",                     # or "reschedule" if you prefer
    )

    submit >> wait