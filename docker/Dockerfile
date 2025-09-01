ARG py_version=3.11.2

FROM python:$py_version-slim-bullseye AS base

RUN apt-get update \
  && apt-get dist-upgrade -y \
  && apt-get install -y --no-install-recommends \
    build-essential=12.9 \
    ca-certificates=20210119 \
    git=1:2.30.2-1+deb11u2 \
    libpq-dev=13.22-0+deb11u1 \
    make=4.3-4.1 \
    openssh-client=1:8.4p1-5+deb11u3 \
    software-properties-common=0.96.20.2-2.1 \
  && apt-get clean \
  && rm -rf \
    /var/lib/apt/lists/* \
    /tmp/* \
    /var/tmp/*

ENV PYTHONIOENCODING=utf-8
ENV LANG=C.UTF-8

RUN python -m pip install --upgrade "pip==24.0" "setuptools==69.2.0" "wheel==0.43.0" --no-cache-dir

FROM base AS dbt-core

ARG commit_ref=main

HEALTHCHECK CMD dbt --version || exit 1

WORKDIR /usr/app/dbt/
ENTRYPOINT ["dbt"]

RUN python -m pip install --no-cache-dir "dbt-core @ git+https://github.com/dbt-labs/dbt-core@${commit_ref}#subdirectory=core"


FROM base AS dbt-postgres

# Add ARG declaration here
ARG commit_ref=main

# Create necessary directories
RUN mkdir -p /root/.dbt

# Install specific protobuf version first
RUN python -m pip install --no-cache-dir "protobuf>=4.23,<5"

# Install dbt packages with specific versions
RUN python -m pip install --no-cache-dir \
    dbt-core==1.7.3 \
    dbt-postgres==1.7.3 \
    dbt-athena-community==1.7.2

# Copy dbt project files
COPY . /usr/app/dbt/

WORKDIR /usr/app/dbt/

# Add wrapper script to handle exit codes properly
RUN echo '#!/bin/bash\n\
set -e\n\
dbt "$@"\n\
exit_code=$?\n\
exit $exit_code' > /usr/local/bin/dbt-wrapper && \
    chmod +x /usr/local/bin/dbt-wrapper

ENTRYPOINT ["/usr/local/bin/dbt-wrapper"]
