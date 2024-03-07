resource "nomad_job" "ghostfolio" {
  depends_on = [
    vault_database_secret_backend_role.ghostfolio,
    postgresql_database.ghostfolio,
    vault_policy.ghostfolio,
  ]

  jobspec          = file("${path.module}/job.nomad.hcl")
  purge_on_destroy = true
}

resource "cloudflare_record" "ghostfolio" {
  zone_id = data.cloudflare_zone.nahsi.zone_id
  name    = "ghostfolio"
  value   = "nahsi.dev"
  type    = "CNAME"
}

resource "vault_policy" "ghostfolio" {
  name   = "ghostfolio"
  policy = <<-EOT
    path "secret/data/ghostfolio"
    {
      capabilities = ["read"]
    }

    path "postgres/creds/ghostfolio"
    {
      capabilities = ["read"]
    }
  EOT
}
