variables {
  versions = {
    grafana = "8.2.1"
    promtail = "2.3.0"
  }
}

job "grafana" {
  datacenters = ["syria"]
  namespace   = "infra"
  type        = "service"

  group "grafana" {
    network {
      port "grafana" {
        to = 3000
      }

      port "promtail" {
        to = 3000
      }
    }

    volume "grafana" {
      type = "host"
      source = "grafana"
    }

    task "grafana" {
      driver = "docker"
      user = "nobody"

      service {
        name = "grafana"
        port = "grafana"
        address_mode = "host"

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.grafana.rule=Host(`grafana.service.consul`)",
          "traefik.http.routers.grafana.tls=true"
        ]

        check {
          name     = "Grafana HTTP"
          type     = "http"
          path     = "/api/health"
          interval = "10s"
          timeout  = "2s"
        }
      }

      vault {
        policies = ["grafana"]
      }

      volume_mount {
        volume = "grafana"
        destination = "/var/lib/grafana"
      }

      env {
        GF_PATHS_CONFIG="/local/grafana/grafana.ini"
        GF_PATHS_PROVISIONING="/local/grafana/provisioning"
      }

      config {
        image = "grafana/grafana:${var.versions.grafana}"

        ports = [
          "grafana"
        ]
      }

      template {
        data = file("grafana.ini")
        destination = "local/grafana/grafana.ini"
      }

      template {
        data = file("provisioning/datasources.yml")
        destination = "local/grafana/provisioning/datasources/datasources.yml"
      }

      template {
        data = <<EOH
{{ with secret "secret/grafana/github" }}{{ .Data.data.client_id }}{{ end }}
EOH
        destination = "secrets/github/client_id"
      }

      template {
        data = <<EOH
{{ with secret "secret/grafana/github" }}{{ .Data.data.secret_id }}{{ end }}
EOH
        destination = "secrets/github/secret_id"
      }

      template {
        data = <<EOH
{{ with secret "secret/grafana/users/admin" }}{{ .Data.data.password }}{{ end }}
EOH
        destination = "secrets/admin_password"
      }

      resources {
        memory = 256
      }
    }

    task "promtail" {
      driver = "docker"

      lifecycle {
        hook    = "poststart"
        sidecar = true
      }

      service {
        name = "promtail"
        port = "promtail"
        tags = ["service=grafana"]
        address_mode = "host"

        check {
          type     = "http"
          path     = "/ready"
          interval = "10s"
          timeout  = "2s"
        }
      }

      resources {
        cpu = 50
        memory = 128
      }

      config {
        image = "grafana/promtail:${var.versions.promtail}"

        args = [
          "-config.file=local/promtail.yml"
        ]

        ports = [
          "promtail"
        ]
      }

      template {
        data = file("promtail.yml")
        destination = "local/promtail.yml"
      }
    }
  }
}
