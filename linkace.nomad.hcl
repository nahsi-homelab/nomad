variables {
  versions = {
    linkace = "1.6.4"
    caddy = "2.4.5-alpine"
  }
}

job "linkace" {
  datacenters = ["syria"]
  type        = "service"

  group "linkace" {
    network {
      port "http" {
        to = 80
      }

      port "php" {
        to = 9000
      }
    }

    task "linkace" {
      driver = "docker"

      vault {
        policies = ["linkace"]
      }

      resources {
        cpu = 100
        memory = 128
      }

      config {
        image = "linkace/linkace:v${var.versions.linkace}"

        ports = [
          "php"
        ]

        mount {
          type = "volume"
          source = "linkace-static"
          target = "/app"
        }

        volumes = [
          "secrets/vars.env:/app/.env"
        ]
      }

      template {
        data = <<EOF
APP_DEBUG=true
APP_KEY=base64:{{ with secret "secret/linkace" }}{{ .Data.data.key }}{{ end }}
DB_CONNECTION=pgsql
DB_HOST=postgres.service.consul
DB_PORT=5432
DB_DATABASE=linkace
DB_USERNAME={{ with secret "database/creds/linkace" }}{{ .Data.username }}{{ end }}
DB_PASSWORD={{ with secret "database/creds/linkace" }}{{ .Data.password }}{{ end }}
EOF

        destination = "secrets/vars.env"
        change_mode = "restart"
        perms = "777"
        env = true
      }
    }

    task "caddy" {
      driver = "docker"

      service {
        name = "linkace"
        port = "http"
      }

      resources {
        cpu = 100
        memory = 128
      }

      config {
        image = "caddy:${var.versions.caddy}"

        ports = [
          "http"
        ]

        volumes = [
          "local/Caddyfile:/etc/caddy/Caddyfile"
        ]

        mount {
          type = "volume"
          source = "linkace-static"
          target = "/app"
        }
      }

      template {
        data = <<EOH
:80 {
  encode zstd gzip

  header X-Frame-Options "SAMEORIGIN"
  header X-XSS-Protection "1; mode=block"
  header X-Content-Type-Options "nosniff"

  root * /app/public
  file_server
  php_fastcgi {{ env "NOMAD_ADDR_php" }}
}
EOH

        destination   = "local/Caddyfile"
        change_mode   = "restart"
      }
    }
  }
}
