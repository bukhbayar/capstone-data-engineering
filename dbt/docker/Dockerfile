FROM python:3.11-slim

# system deps
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl gnupg && \
    rm -rf /var/lib/apt/lists/*

# dbt core + athena adapter + awscli
# Pin to a matching series; adjust if your project needs a different dbt minor.
RUN pip install --no-cache-dir \
      "dbt-core==1.7.13" \
      "dbt-athena-community==1.7.7" \
      "awscli>=1.32" "boto3>=1.34"

# non-root user
RUN useradd -m app
USER app
WORKDIR /app

# default entrypoint: use shell so Batch CMD strings work nicely
ENTRYPOINT ["bash","-lc"]
CMD ["dbt --help"]