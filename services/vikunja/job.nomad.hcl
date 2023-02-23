variable "version" {
  type = string
}

job "vikunja" {
  datacenters = ["syria"]
  namespace   = "services"

  group "api" {
    network {
      port "http" {
        to = 3456
      }
    }

    service {
      name = "vikunja-api"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.vikunja-api.entrypoints=public",
        "traefik.http.routers.vikunja-api.rule=Host(`tasks.nahsi.dev`) && (PathPrefix(`/api/v1`) || PathPrefix(`/dav/`) || PathPrefix(`/.well-known/`))",
      ]

      check {
        name     = "vikunja HTTP"
        port     = "http"
        type     = "http"
        path     = "/health"
        interval = "10s"
        timeout  = "1s"
      }
    }

    volume "vikunja" {
      type   = "host"
      source = "vikunja"
    }

    task "vikunja" {
      driver = "docker"

      vault {
        policies = ["vikunja"]
      }

      env {
        VIKUNJA_SERVICE_FRONTENDURL         = "https://tasks.nahsi.dev"
        VIKUNJA_SERVICE_TIMEZONE            = "Europe/Athens"
        VIKUNJA_SERVICE_ENABLEREGISTRATION  = false
        VIKUNJA_SERVICE_ENABLEMAILREMINDERS = false

        VIKUNJA_LOG_LEVEL = "info"
        VIKUNJA_LOG_HTTP  = false

        VIKUNJA_FILES_BASEPATH = "/files"
      }

      volume_mount {
        volume      = "vikunja"
        destination = "/files"
      }

      config {
        image = "vikunja/api:${var.version}"
        ports = [
          "http",
        ]
      }

      template {
        data = <<-EOF
        {{- with secret "secret/vikunja/secret" }}
        VIKUNJA_SERVICE_JWTSECRET='{{ .Data.data.secret }}'
        {{- end }}
        EOF

        destination = "secrets/secret.env"
        env         = true
      }

      template {
        data = <<-EOF
        {{- with secret "secret/vikunja/mail" }}
        VIKUNJA_MAILER_ENABLED=true
        VIKUNJA_MAILER_HOST=mail.nahsi.dev
        VIKUNJA_MAILER_PORT=465
        VIKUNJA_MAILER_USERNAME='{{ .Data.data.username }}'
        VIKUNJA_MAILER_PASSWORD='{{ .Data.data.password }}'
        VIKUNJA_MAILER_FROMMAIL=vikunja@nahsi.dev
        {{- end }}
        EOF

        destination = "secrets/mail.env"
        env         = true
      }

      template {
        data = <<-EOF
        {{- with secret "postgres/creds/vikunja" }}
        VIKUNJA_DATABASE_TYPE=postgres
        VIKUNJA_DATABASE_HOST=master.postgres.service.consul
        VIKUNJA_DATABASE_DATABASE=vikunja
        VIKUNJA_DATABASE_USER={{ .Data.username }}
        VIKUNJA_DATABASE_PASSWORD={{ .Data.password }}
        {{- end }}
        EOF

        destination = "secrets/db.env"
        env         = true
      }

      resources {
        cpu        = 500
        memory     = 256
        memory_max = 512
      }
    }
  }

  group "frontend" {
    network {
      port "http" {
        to = 80
      }
    }

    service {
      name = "vikunja-frontend"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.vikunja-frontend.entrypoints=public",
        "traefik.http.routers.vikunja-frontend.rule=Host(`tasks.nahsi.dev`)",
      ]
    }

    task "frontend" {
      driver = "docker"

      config {
        image = "vikunja/frontend:${var.version}"
        ports = [
          "http",
        ]
      }

      resources {
        cpu        = 100
        memory     = 64
        memory_max = 128
      }
    }
  }
}
