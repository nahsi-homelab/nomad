# vim: set ft=hcl sw=2 ts=2 :
job "caddy" {

  datacenters = ["syria"]

  type        = "service"

  group "caddy" {
    network {
      port "http" {
        static = 80
        to = 80
      }
    }

    service {
      name = "caddy"
      port = "http"
    }

    task "caddy" {
      driver = "podman"

      config {
        image = "docker://caddy:2.3.0-alpine"

        ports = [
          "http"
        ]

        volumes = [
          "local/Caddyfile:/etc/caddy/Caddyfile",
          "/mnt/apps/caddy/:/data"
        ]
      }

      template {
        data = <<EOH
:80 {
  {{ range service "homer" }}
  reverse_proxy {{ .Address }}:{{ .Port }}
  {{ end }}
}
EOH

        change_mode   = "restart"
        destination   = "local/Caddyfile"
      }

      resources {
        cpu = 100
        memory = 300
      }
    }
  }
}
