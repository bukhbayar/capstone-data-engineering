# docker/dbt-athena.Dockerfile
FROM python:3.11-slim

ENV PIP_NO_CACHE_DIR=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# System packages needed for many python wheels (cryptography, pyarrow, etc.)
# Note: no compilers if we can use prebuilt wheels, but keep basic build tools handy.
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential \
      curl ca-certificates git \
      libssl-dev libffi-dev \
      # optional but often useful:
      # libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Stabilize Python packaging toolchain (new setuptools versions broke some builds)
RUN python -m pip install --upgrade \
      "pip<25" "setuptools<70" "wheel>=0.42"

# Install dbt + Athena adapter + AWS libs (versions known to work together)
# If you still hit resolver issues, add:  --verbose  to see exact failure.
RUN pip install --no-cache-dir \
      "dbt-core==1.7.13" \
      "dbt-athena-community==1.7.7" \
      "awscli>=1.32" "boto3>=1.34"

# Non-root user
RUN useradd -m app
USER app
WORKDIR /app

ENTRYPOINT ["bash","-lc"]
CMD ["dbt --help"]