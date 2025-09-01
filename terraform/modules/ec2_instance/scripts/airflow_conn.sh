#!/usr/bin/env bash
set -euo pipefail

AIRFLOW_BIN="${AIRFLOW_BIN:-airflow}"   # or /home/airflow/venv/bin/airflow

# --------- Inputs (edit defaults or export as env vars) ----------
POSTGRES_HOST="${POSTGRES_HOST:-10.20.1.50}"
POSTGRES_DB="${POSTGRES_DB:-bootcamp_db}"
POSTGRES_USER="${POSTGRES_USER:-bootcamp_user}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-bootcamp_password}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"

# --------- Helpers ----------
upsert_conn() {
  local id="$1"; shift
  if $AIRFLOW_BIN connections get "$id" >/dev/null 2>&1; then
    echo "[conn:$id] exists → overwriting"
    $AIRFLOW_BIN connections add "$id" --overwrite "$@"
  else
    echo "[conn:$id] creating"
    $AIRFLOW_BIN connections add "$id" "$@"
  fi
}

# --------- Postgres connection ---------
PG_URI="postgresql+psycopg2://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:${POSTGRES_PORT}/${POSTGRES_DB}"
upsert_conn postgres_default \
  --conn-uri "$PG_URI" \
  --conn-description "Postgres on EC2 (bootcamp_db)"

echo "Airflow connections ensured."