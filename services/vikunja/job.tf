locals {
  version = "0.20"
}

resource "nomad_job" "vikunja" {
  depends_on = [
    vault_database_secret_backend_role.vikunja,
    postgresql_database.vikunja,
    vault_policy.vikunja,
  ]

  jobspec          = file("${path.module}/job.nomad.hcl")
  purge_on_destroy = true

  hcl2 {
    enabled = true

    vars = {
      version = local.version
    }
  }
}

resource "cloudflare_record" "vikunja" {
  zone_id = data.cloudflare_zone.nahsi.zone_id
  name    = "tasks"
  value   = "nahsi.dev"
  type    = "CNAME"
}

resource "vault_policy" "vikunja" {
  name   = "vikunja"
  policy = <<-EOT
    path "secret/data/vikunja/secret"
    {
      capabilities = ["read"]
    }

    path "secret/data/vikunja/mail"
    {
      capabilities = ["read"]
    }

    path "postgres/creds/vikunja"
    {
      capabilities = ["read"]
    }
  EOT
}
