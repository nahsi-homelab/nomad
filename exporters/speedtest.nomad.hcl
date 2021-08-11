job "speedtest" {
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

  group "speedtest" {
    count = 2

    network {
      port "http" {
        to = 9798
      }
    }

    service {
      name = "speedtest"
      tags = ["dc=${node.datacenter}"]
      port = "http"

      check {
        name = "SpeedTest HTTP"
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "speedtest" {
      driver = "docker"

      config {
        image = "miguelndecarvalho/speedtest-exporter:v3.3.2"

        ports = [
          "http"
        ]
      }

      resources {
        memory = 128
      }
    }
  }
}
