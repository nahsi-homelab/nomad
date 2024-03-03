resource "mysql_database" "wish" {
  name                  = "wish"
  default_character_set = "utf8mb4"
  default_collation     = "utf8mb4_unicode_ci"
}

resource "mysql_user" "wish" {
  user = "wish"
  host = "%"
}

resource "mysql_grant" "wish" {
  user       = mysql_user.wish.user
  host       = mysql_user.wish.host
  database   = mysql_database.wish.name
  privileges = ["ALL PRIVILEGES"]
}

resource "vault_database_secret_backend_static_role" "wish" {
  backend  = "mariadb"
  name     = "wish"
  db_name  = "mariadb"
  username = "wish"
  rotation_statements = [
    "SET PASSWORD FOR '{{name}}'@'${mysql_user.wish.host}' = PASSWORD('{{password}}');"
  ]
  rotation_period = 604800 # 7d
}

resource "consul_keys" "configs" {
  key {
    path   = "configs/services/wish/config.php"
    value  = file("config.php")
    delete = true
  }
}

resource "nomad_job" "wish" {
  depends_on = [
    vault_database_secret_backend_static_role.wish,
    mysql_database.wish,
    vault_policy.wish,
  ]

  jobspec          = file("${path.module}/job.nomad.hcl")
  purge_on_destroy = true
}

resource "cloudflare_record" "wish" {
  zone_id = data.cloudflare_zone.nahsi.zone_id
  name    = "wish"
  value   = "nahsi.dev"
  type    = "CNAME"
}

resource "vault_policy" "wish" {
  name   = "wish"
  policy = <<-EOT
    path "mariadb/static-creds/wish"
    {
      capabilities = ["read"]
    }
  EOT
}
