variables {
  version = "1.8.4"
}

job "linkding" {
  datacenters = ["syria"]
  type        = "service"

  group "linkding" {
    network {
      port "http" {
        to = 9090
      }
    }

    service {
      name = "links"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.linkding.rule=Host(`links.service.consul`)",
        "traefik.http.routers.linkding.tls=true"
      ]
    }

    volume "linkding" {
      type = "host"
      source = "linkding"
    }

    task "linkding" {
      driver = "docker"

      volume_mount {
        volume = "linkding"
        destination = "/etc/linkding/data"
      }

      resources {
        memory = 256
      }

      env {
        LD_DISABLE_BACKGROUND_TASKS="True"
      }

      config {
        image = "sissbruecker/linkding:${var.version}"

        ports = [
          "http"
        ]
      }
    }
  }
}
