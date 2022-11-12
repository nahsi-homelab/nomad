variables {
  versions = {
    vaultwarden = "1.26.0-alpine"
  }
}

job "vaultwarden" {
  datacenters = [
    "syria",
  ]
  namespace = "services"

  group "vaultwarden" {
    count = 1

    network {
      port "http" {
        to = 80
      }
    }

    service {
      name = "vaultwarden"
      port = "http"

      meta {
        alloc_id = NOMAD_ALLOC_ID
      }

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.vaultwarden.entrypoints=public",
        "traefik.http.routers.vaultwarden.rule=Host(`vaultwarden.nahsi.dev`)",
      ]

      check {
        name     = "vaultwarden HTTP"
        type     = "http"
        path     = "/alive"
        interval = "20s"
        timeout  = "1s"
      }
    }

    volume "vaultwarden" {
      type   = "host"
      source = "vaultwarden"
    }

    task "vaultwarden" {
      driver = "docker"
      user   = "nobody"

      vault {
        policies = ["vaultwarden"]
      }

      volume_mount {
        volume      = "vaultwarden"
        destination = "/data"
      }

      env {
        DOMAIN          = "https://vaultwarden.nahsi.dev"
        SIGNUPS_VERIFY  = true
        SIGNUPS_ALLOWED = false
      }

      config {
        image = "vaultwarden/server:${var.versions.vaultwarden}"

        ports = [
          "http",
        ]
      }


      template {
        data = <<-EOH
        {{- with secret "postgres/creds/vaultwarden" }}
        DATABASE_URL=postgresql://{{ .Data.username }}:{{ .Data.password }}@master.postgres.service.consul:5432/vaultwarden
        {{- end }}
        EOH

        destination = "secrets/db.env"
        env         = true
      }

      template {
        data = <<-EOH
        SMTP_HOST=mail.nahsi.dev
        SMTP_FROM=vaultwarden@nahsi.dev
        SMTP_FROM_NAME=vaultwarden
        SMTP_SECURITY=force_tls
        SMTP_PORT=465
        {{- with secret "secret/vaultwarden/smtp" }}
        SMTP_USERNAME={{ .Data.data.username }}
        SMTP_PASSWORD={{ .Data.data.password }}
        {{- end }}
        EOH

        destination = "secrets/smtp.env"
        env         = true
      }

      resources {
        cpu        = 100
        memory     = 128
        memory_max = 256
      }
    }
  }
}
