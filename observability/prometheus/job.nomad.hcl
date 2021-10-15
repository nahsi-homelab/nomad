variables {
  version = "2.30.3"
}

job "prometheus" {
  datacenters = ["syria"]
  type        = "service"

  group "prometheus" {
    network {
      port "http" {
        to = 9090
        static = 9090
      }
    }

    service {
      name = "prometheus"
      port = "http"

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

    volume "prometheus" {
      type = "host"
      source = "prometheus"
    }

    task "prometheus" {
      driver = "docker"
      user = "nobody"

      volume_mount {
        volume = "prometheus"
        destination = "/var/lib/prometheus"
      }

      config {
        image = "prom/prometheus:v${var.version}"

        ports = [
          "http"
        ]

        extra_hosts = [
          "host.docker.internal:host-gateway"
        ]

        args = [
          "--web.listen-address=0.0.0.0:${NOMAD_PORT_http}",
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
  }
}
