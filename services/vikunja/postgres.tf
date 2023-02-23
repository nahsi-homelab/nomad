provider "postgresql" {
  host            = "master.postgres.service.consul"
  port            = 5432
  database        = "postgres"
  username        = var.postgres_username
  password        = var.postgres_password
  superuser       = false
  sslmode         = "disable"
  connect_timeout = 15
}

variable "postgres_username" {
  type      = string
  sensitive = true
}

variable "postgres_password" {
  type      = string
  sensitive = true
}

data "terraform_remote_state" "postgres" {
  backend = "consul"

  config = {
    address = "consul.service.consul:8500"
    scheme  = "http"
    path    = "terraform/postgres"
  }
}

resource "postgresql_role" "vikunja" {
  name    = "vikunja"
  inherit = true
}

resource "postgresql_database" "vikunja" {
  name  = "vikunja"
  owner = postgresql_role.vikunja.name
}

resource "postgresql_default_privileges" "vikunja" {
  role     = postgresql_role.vikunja.name
  database = postgresql_database.vikunja.name
  schema   = "public"

  owner       = "vikunja"
  object_type = "table"
  privileges = [
    "SELECT",
    "INSERT",
    "UPDATE",
    "DELETE",
    "TRUNCATE",
  ]
}

resource "vault_database_secret_backend_role" "vikunja" {
  backend = data.terraform_remote_state.postgres.outputs.database_path
  name    = "vikunja"
  db_name = data.terraform_remote_state.postgres.outputs.backend_connection

  default_ttl = 604800  # 7d
  max_ttl     = 2592000 # 30d

  creation_statements = [
    "CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';",
    "GRANT vikunja TO \"{{name}}\";",
    "ALTER ROLE \"{{name}}\" SET ROLE vikunja;",
  ]

  revocation_statements = [
    "SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE pg_stat_activity.usename = '{{name}}';",
    "DROP ROLE IF EXISTS \"{{name}}\";"
  ]
}
