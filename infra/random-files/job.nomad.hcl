job "random-files" {
  datacenters = [
    "syria",
    "asia",
    "pontus"
  ]

  namespace = "infra"
  type      = "service"

  constraint {
    distinct_property = "${node.datacenter}"
  }

  group "random-files" {
    count = 3
    ephemeral_disk {
      sticky = true
    }

    network {
      port "web" {
        to = 80
      }
    }

    service {
      name = "random-files"
      port = "web"
      
      tags = [
        "ingress.enable=true",
        "ingress.http.routers.random-files.entrypoints=https",
        "ingress.http.routers.random-files.tls=true",
        "ingress.http.routers.random-files.rule=Host(`${NOMAD_DC}.nahsi.dev`)"
      ]

      check {
        type     = "http"
        path     = "/"
        port     = "web"
        interval = "30s"
        timeout  = "2s"
      }
    }

    task "random-files" {
      driver = "docker"

      env {
        FILES = "128 256 512 1024"
        SERVER_ROOT = "/alloc/data/files"
        SERVER_PATH = "/random-files"
      }

      config {
        image = "nahsihub/random-files"
        ports = ["web"]
      }

      resources {
        memory = 32
      }
    }
  }
}
