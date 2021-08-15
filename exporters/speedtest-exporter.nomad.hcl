job "speedtest-exporter" {
  datacenters = ["syria", "asia"]
  type        = "service"

  spread {
    attribute = "${node.datacenter}"

    target "syria" {
      percent = 50
    }

    target "asia" {
      percent = 50
    }
  }

  group "speedtest-exporter" {
    count = 2

    network {
      port "http" {
        to = 9876
      }
    }

    service {
      name = "speedtest-exporter"
      tags = ["dc=${node.datacenter}"]
      port = "http"

      check {
        name = "speedtest-exporter HTTP"
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "speedtest-exporter" {
      driver = "docker"

      config {
        image = "ghcr.io/caarlos0/speedtest-exporter:v1.1.4"

        ports = [
          "http"
        ]

        args = [
          "--refresh.interval=3h"
        ]
      }

      resources {
        memory = 128
      }
    }
  }
}
