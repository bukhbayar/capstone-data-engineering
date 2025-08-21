
locals {
  name = "${var.project}-${var.environment}"

  db_bootstrap_sql = join("\n\n", [
    for db in var.databases : <<-SQL
      CREATE DATABASE ${db.name};
      CREATE ROLE ${db.user} LOGIN PASSWORD '${db.password}';
      GRANT ALL PRIVILEGES ON DATABASE ${db.name} TO ${db.user};

      \c ${db.name}

      -- let the airflow role use and create objects in public
      GRANT USAGE, CREATE ON SCHEMA public TO ${db.user};

      -- if objects already exist and aren't owned by airflow, grant on them:
      GRANT SELECT, INSERT, UPDATE, DELETE, TRIGGER ON ALL TABLES IN SCHEMA public TO ${db.user};
      GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO ${db.user};

      -- ensure future objects are usable by airflow
      ALTER DEFAULT PRIVILEGES IN SCHEMA public
        GRANT SELECT, INSERT, UPDATE, DELETE, TRIGGER ON TABLES TO ${db.user};
      ALTER DEFAULT PRIVILEGES IN SCHEMA public
        GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO ${db.user};

    SQL
  ])
}