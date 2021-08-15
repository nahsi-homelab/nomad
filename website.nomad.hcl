job "website" {

  datacenters = ["syria"]
  type        = "service"

  group "website" {
    network {
      port "http" {
        static = 80
        to = 80
        host_network = "public"
      }

      port "https" {
        static = 443
        to = 443
        host_network = "public"
      }
    }

    service {
      name = "website"
      port = "https"
    }

    task "website" {
      driver = "docker"

      vault {
        policies = ["public-cert"]
      }

      config {
        image = "caddy:2.4.3-alpine"

        ports = [
          "http",
          "https"
        ]

        volumes = [
          "local/Caddyfile:/etc/caddy/Caddyfile",
          "/mnt/apps/caddy/:/data"
        ]
      }

      template {
        data = <<EOH
nahsi.dev:443 {
  tls /secrets/cert.pem /secrets/key.pem
  encode zstd gzip
  respond "nothing here yet"
}

jellyfin.nahsi.dev:443 {
  tls /secrets/cert.pem /secrets/key.pem

  encode zstd gzip

  @websockets {
    header Connection *Upgrade*
    header Upgrade websocket
  }


  route /* {
    error /metrics* "Unauthorized" 403
    reverse_proxy {
      {{- range service "jellyfin" }}
      to {{ .Address }}:{{ .Port }}
      {{- end }}
    }
  }
}
EOH

        destination   = "local/Caddyfile"
        change_mode   = "restart"
      }

      template {
        data = <<EOH
{{- with secret "secret/certificate" -}}
{{ .Data.data.certificate }}{{ end }}
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
