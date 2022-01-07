variables {
  version = "2.4.5-0.88.1"
}

job "website" {
  datacenters = ["syria"]
  namespace   = "services"

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
        "ingress.http.routers.website.rule=Host(`blog.nahsi.dev`)",
        "ingress.http.routers.website.tls=true",
      ]
    }

    task "website" {
      driver = "docker"
      user   = "nobody"

      vault {
        policies = ["website"]
      }

      config {
        image      = "nahsihub/caddy-hugo:${var.version}"
        force_pull = true

        ports = [
          "http"
        ]

        volumes = [
          "local/Caddyfile:/etc/caddy/Caddyfile"
        ]
      }

      template {
        data        = file("Caddyfile")
        destination = "local/Caddyfile"
      }

      template {
        data = <<-EOH
        WEBHOOK_SECRET={{ with secret "secret/website/webhook" }}{{ .Data.data.secret }}{{ end }}
        EOH

        destination = "secrets/webhook.env"
        env         = true
      }

      resources {
        memory = 64
      }
    }
  }
}
