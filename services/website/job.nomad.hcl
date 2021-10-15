variables {
  version = "2.4.5"
}

job "website" {
  datacenters = ["syria"]
  type        = "service"

  group "website" {
    network {
      port "http" {
        to = 80
      }
    }

    service {
      name = "website"
      port = "http"

      tags = [
        "ingress.enable=true",
        "ingress.http.routers.website.rule=Host(`nahsi.dev`)",
        "ingress.http.routers.website.tls=true"
      ]
    }

    task "website" {
      driver = "docker"

      vault {
        policies = ["public-cert"]
      }

      config {
        image = "caddy:${var.version}-alpine"

        ports = [
          "http"
        ]

        volumes = [
          "local/Caddyfile:/etc/caddy/Caddyfile"
        ]
      }

      template {
        data = <<EOH
nahsi.dev:80 {
  encode zstd gzip
  respond "nothing here yet"
}
EOH

        destination   = "local/Caddyfile"
        change_mode   = "restart"
      }

      template {
        data = <<EOH
{{- with secret "secret/certificate" -}}
{{ .Data.data.ca_bundle }}{{ end }}
EOH

        change_mode   = "restart"
        destination   = "secrets/cert.pem"
      }

      template {
        data = <<EOH
{{- with secret "secret/certificate" -}}
{{ .Data.data.key }}{{ end }}
EOH

        change_mode   = "restart"
        destination   = "secrets/key.pem"
      }

      resources {
        memory = 64
      }
    }
  }
}
