job "network-exporter" {
  datacenters = [
    "syria",
  ]
  namespace = "observability"

  constraint {
    distinct_property = node.unique.name
  }

  group "network-exporter" {
    count = 2
    ephemeral_disk {
      sticky  = true
      migrate = true
      size    = 3000
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
        "traefik.enable=true",
        "traefik.http.routers.random-files.entrypoints=public",
        "traefik.http.routers.random-files.rule=Host(`asia.nahsi.dev`) || Host(`syria.nahsi.dev`)"
      ]

      check {
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "random-files" {
      driver = "docker"
      user   = "nobody"

      resources {
        cpu    = 10
        memory = 64
      }

      env {
        FILES       = "128 256 512 1024 2048"
        SERVER_ROOT = "/alloc/data/files"
      }

      config {
        image = "nahsihub/random-files"
        ports = ["web"]
      }
    }
  }
}
