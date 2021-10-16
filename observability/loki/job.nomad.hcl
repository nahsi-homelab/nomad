variables {
  versions = {
    loki = "2.3.0"
    promtail = "2.3.0"
  }
}

job "loki" {
  datacenters = ["syria"]
  namespace   = "infra"
  type        = "service"

  group "loki" {
    network {
      port "loki" {
        to = 3100
        static = 3100
      }

      port "promtail" {
        to = 3000
      }
    }

    volume "loki" {
      type   = "host"
      source = "loki"
    }

    task "loki" {
      driver = "docker"
      user   = "nobody"

      service {
        name = "loki"
        port = "loki"
        address_mode = "host"

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.loki.rule=Host(`loki.service.consul`)",
          "traefik.http.routers.loki.tls=true"
        ]

        check {
          name     = "Loki HTTP"
          type     = "http"
          path     = "/ready"
          interval = "10s"
          timeout  = "2s"
        }
      }

      volume_mount {
        volume      = "loki"
        destination = "/loki"
      }

      config {
        image = "grafana/loki:${var.versions.loki}"

        ports = [
          "loki"
        ]

        args = [
          "-config.file=/local/loki.yml"
        ]
      }

      template {
        data = file("loki.yml")
        change_mode   = "signal"
        change_signal = "SIGHUP"
        destination   = "local/loki.yml"
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
