
locals {
  name = "${var.project}-${var.environment}"

  db_bootstrap_sql = join("\n\n", [
    for db in var.databases : <<-SQL
      CREATE DATABASE ${db.name};
      CREATE ROLE ${db.user} LOGIN PASSWORD '${db.password}';
      GRANT ALL PRIVILEGES ON DATABASE ${db.name} TO ${db.user};
      GRANT USAGE, CREATE ON SCHEMA public TO ${db.user};
    SQL
  ])
}