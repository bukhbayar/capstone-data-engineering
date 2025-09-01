# ---- Build args (optional) ----
ARG PY_VERSION=3.11-slim-bullseye

# ---- Base runtime ----
FROM python:${PY_VERSION}

ENV PIP_NO_CACHE_DIR=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    LANG=C.UTF-8

# Minimal system deps (libpq for dbt-postgres, git for deps; build-essential for any wheels)
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential \
      ca-certificates \
      git \
      libpq-dev \
      openssh-client \
    && rm -rf /var/lib/apt/lists/*

# Stabilize packaging toolchain (avoid recent breakages)
RUN python -m pip install --upgrade \
      "pip<25" "setuptools<70" "wheel>=0.42"

# ---- dbt + adapters + AWS + protobuf pins ----
# Known-good set that avoids the protobuf crash:
#  - dbt-core/dbt-postgres 1.7.13
#  - dbt-athena-community 1.7.7
#  - protobuf >=4.23,<5  (critical)
#  - googleapis-common-protos <2  (pairs with protobuf v4)
RUN pip install --no-cache-dir \
      "dbt-core==1.7.13" \
      "dbt-postgres==1.7.13" \
      "dbt-athena-community==1.7.7" \
      "protobuf>=4.23,<5" \
      "googleapis-common-protos<2" \
      "awscli>=1.32" "boto3>=1.34"

# Non-root user
RUN useradd -m app
USER app
WORKDIR /app

# Optional: copy your dbt project into the image (uncomment if desired)
# COPY --chown=app:app . /app
# RUN dbt deps  # if your project has packages.yml

# Tiny wrapper keeps entrypoint simple and exit codes correct
COPY --chown=app:app <<'SH' /usr/local/bin/dbt-wrapper
#!/usr/bin/env bash
set -euo pipefail
exec dbt "$@"
SH
USER root
RUN chmod +x /usr/local/bin/dbt-wrapper
USER app

HEALTHCHECK CMD dbt --version || exit 1
ENTRYPOINT ["/usr/local/bin/dbt-wrapper"]