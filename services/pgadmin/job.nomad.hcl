variables {
  versions = {
    pgadmin = "6.9"
  }
}

job "pgadmin" {
  datacenters = ["syria"]
  namespace   = "services"

  group "pgadmin" {
    network {
      port "http" {
        to = 80
      }
    }

    service {
      name = "pgadmin"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.pgadmin.entrypoints=https",
        "traefik.http.routers.pgadmin.rule=Host(`pgadmin.service.consul`)",
      ]
    }

    volume "pgadmin" {
      type   = "host"
      source = "pgadmin"
    }

    task "pgadmin" {
      driver = "docker"
      user   = "5050"

      vault {
        policies = ["pgadmin"]
      }

      volume_mount {
        volume      = "pgadmin"
        destination = "/var/lib/pgadmin"
      }

      config {
        image = "dpage/pgadmin4:${var.versions.pgadmin}"

        ports = [
          "http",
        ]
      }

      template {
        data = <<-EOF
        {{- with secret "secret/pgadmin/admin" }}
        PGADMIN_DEFAULT_EMAIL='{{ .Data.data.username }}'
        PGADMIN_DEFAULT_PASSWORD='{{ .Data.data.password }}'
        {{- end }}

        {{- with secret "secret/pgadmin/email" }}
        PGADMIN_CONFIG_MAIL_SERVER="'mail.nahsi.dev'"
        PGADMIN_CONFIG_MAIL_PORT=465
        PGADMIN_CONFIG_MAIL_USE_SSL=True
        PGADMIN_CONFIG_MAIL_USE_TLS=False
        PGADMIN_CONFIG_MAIL_USERNAME="'{{ .Data.data.username }}'"
        PGADMIN_CONFIG_MAIL_PASSWORD="'{{ .Data.data.password }}'"
        {{- end }}

        PGADMIN_CONFIG_SECURITY_EMAIL_SENDER="'pgadmin@nahsi.dev'"
        EOF

        destination = "secrets/secrets.env"
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
