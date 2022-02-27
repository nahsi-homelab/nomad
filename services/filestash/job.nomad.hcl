job "filestash" {
  datacenters = [
    "syria",
    "asia"
  ]
  namespace = "services"

  group "filestash" {
    network {
      port "http" {
        to = 8334
      }
    }

    service {
      name = "filestash"
      port = "http"

      tags = [
        "ingress.enable=true",
        "ingress.http.routers.filestash.entrypoints=https",
        "ingress.http.routers.filestash.rule=Host(`files.nahsi.dev`)",
      ]
    }

    volume "filestash" {
      source = "filestash"
      type   = "host"
    }

    task "filestash" {
      driver = "docker"

      resources {
        cpu        = 500
        memory     = 128
        memory_max = 512
      }

      volume_mount {
        volume      = "filestash"
        destination = "/app/data/state"
      }

      config {
        image = "machines/filestash"
        ports = ["http"]
      }
    }
  }
}
