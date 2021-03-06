job "victoria-metrics" {
  datacenters = ["syria"]

  group "victoria-metrics" {
    count = 1

    network {
      port "http" {}
    }

    service {
      name = "victoria-metrics"
      tags = ["observability"]
      port = "http"

      check {
        name     = "VictoriaMetrics HTTP"
        type     = "http"
        path     = "/health"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "victoria-metrics" {
      driver = "podman"

      config {
        image = "docker://victoriametrics/victoria-metrics:v1.54.1"

        ports = [
          "http"
        ]

        args = [
          "-httpListenAddr=:${NOMAD_PORT_http}",
          "-retentionPeriod=6",
          "-storageDataPath=/data",
          "-selfScrapeInterval=15s"
        ]

        volumes = [
          "/mnt/apps/victoria-metrics:/data"
        ]
      }

      resources {
        cpu    = 300
        memory = 512
      }
    }
  }
}
