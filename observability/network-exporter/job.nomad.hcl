variables {
  versions = {
    network-exporter = "1.4.0"
  }
}

job "network-exporter" {
  datacenters = [
    "syria",
    "asia",
    "pontus"
  ]

  namespace = "infra"

  constraint {
    distinct_property = node.datacenter
  }

  group "network-exporter" {
    count = 3
    ephemeral_disk {
      sticky  = true
      migrate = true
      size    = 2000
    }

    network {
      port "web" {
        to = 80
      }

      port "exporter" {
        to = 9427
      }
    }

    task "random-files" {
      driver = "docker"
      user   = "nobody"

      resources {
        cpu    = 10
        memory = 16
      }

      env {
        FILES = "128 256 512 1024"
        SERVER_ROOT = "/alloc/data/files"
      }

      service {
        name = "random-files"
        port = "web"

        tags = [
          "ingress.enable=true",
          "ingress.http.routers.random-files.entrypoints=https",
          "ingress.http.routers.random-files.tls=true",
          "ingress.http.routers.random-files.rule=Host(`${node.datacenter}.nahsi.dev`)"
        ]

      check {
        type     = "http"
        path     = "/"
        interval = "20s"
        timeout  = "2s"
      }
    }


      config {
        image = "nahsihub/random-files"
        ports = ["web"]
      }
    }

    task "network-exporter" {
      driver = "docker"
      user   = "nobody"

      resources {
        cpu    = 10
        memory = 32
      }

      service {
        name = "network-exporter"
        port = "exporter"

        meta {
          dc = node.datacenter
        }

        check {
          type     = "http"
          path     = "/"
          interval = "20s"
          timeout  = "2s"
        }
      }

      config {
        image = "syepes/network_exporter:${var.versions.network-exporter}"
        ports = ["exporter"]

        args = [
          "/app/network_exporter",
          "--config.file=/local/network_exporter.yml"
        ]
      }

      template {
        data        = file("network_exporter.yml")
        destination = "local/network_exporter.yml"
      }
    }
  }
}
