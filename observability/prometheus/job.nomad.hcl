variables {
  versions = {
    prometheus = "2.30.3"
    promtail = "2.3.0"
  }
}

job "prometheus" {
  datacenters = ["syria"]
  namespace   = "infra"
  type        = "service"

  group "prometheus" {
    network {
      port "prometheus" {
        to = 9090
        static = 9090
      }

      port "promtail" {
        to = 3000
      }
    }

    volume "prometheus" {
      type = "host"
      source = "prometheus"
    }

    task "prometheus" {
      driver = "docker"
      user = "nobody"

      service {
        name = "prometheus"
        port = "prometheus"
        address_mode = "host"

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.prometheus.rule=Host(`prometheus.service.consul`)",
          "traefik.http.routers.prometheus.tls=true"
        ]

        check {
          name     = "Prometheus HTTP"
          type     = "http"
          path     = "/-/healthy"
          interval = "10s"
          timeout  = "2s"
        }
    }


      volume_mount {
        volume = "prometheus"
        destination = "/var/lib/prometheus"
      }

      config {
        image = "prom/prometheus:v${var.versions.prometheus}"

        ports = [
          "prometheus"
        ]

        extra_hosts = [
          "host.docker.internal:host-gateway"
        ]

        args = [
          "--web.listen-address=0.0.0.0:9090",
          "--config.file=/local/prometheus.yml",
          "--storage.tsdb.retention.time=1y",
          "--storage.tsdb.path=/var/lib/prometheus",
          "--web.enable-lifecycle"
        ]
      }

      template {
        data = file("prometheus.yml")
        change_mode   = "signal"
        change_signal = "SIGHUP"
        destination   = "local/prometheus.yml"
      }

      resources {
        cpu    = 300
        memory = 512
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
        tags = ["service=prometheus"]
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
