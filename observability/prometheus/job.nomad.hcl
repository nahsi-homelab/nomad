variables {
  versions = {
    prometheus = "2.30.3"
    promtail   = "2.4.1"
  }
}

job "prometheus" {
  datacenters = ["syria"]
  namespace   = "observability"

  group "prometheus" {
    network {
      port "prometheus" {
        to     = 9090
        static = 9090
      }
      port "promtail" {
        to = 3000
      }
    }

    service {
      name = "promtail"
      port = "promtail"

      meta {
        sidecar_to = "prometheus"
      }

      check {
        type     = "http"
        path     = "/ready"
        interval = "10s"
        timeout  = "2s"
      }
    }

    service {
      name = "prometheus"
      port = "prometheus"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.prometheus.rule=Host(`prometheus.service.consul`)",
        "traefik.http.routers.prometheus.tls=true"
      ]

      meta {
        dashboard = "UDdpyzz7z"
      }

      check {
        name     = "Prometheus HTTP"
        type     = "http"
        path     = "/-/healthy"
        interval = "10s"
        timeout  = "2s"
      }
    }

    volume "prometheus" {
      type   = "host"
      source = "prometheus"
    }

    task "prometheus" {
      driver = "docker"
      user   = "nobody"

      vault {
        policies = ["prometheus"]
      }

      volume_mount {
        volume      = "prometheus"
        destination = "/var/lib/prometheus"
      }

      config {
        image = "prom/prometheus:v${var.versions.prometheus}"

        ports = [
          "prometheus"
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
        data          = file("prometheus.yml")
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

      resources {
        cpu    = 50
        memory = 64
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
        data        = file("promtail.yml")
        destination = "local/promtail.yml"
      }
    }
  }
}
