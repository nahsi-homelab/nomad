variables {
  version = "0.13.5"
}

job "polaris" {
  datacenters = ["syria"]
  namespace   = "services"

  group "polaris" {
    ephemeral_disk {
      sticky  = true
      migrate = true
    }

    network {
      port "http" {}
    }

    volume "polaris" {
      type   = "host"
      source = "polaris"
    }

    volume "music" {
      type      = "host"
      source    = "music-nahsi"
      read_only = true
    }

    service {
      name = "polaris"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.polaris.entrypoints=https",
        "traefik.http.routers.polaris.rule=Host(`polaris.service.consul`)",
      ]
    }

    task "polaris" {
      driver = "docker"

      volume_mount {
        volume      = "polaris"
        destination = "/var/lib/polaris"
      }

      volume_mount {
        volume      = "music"
        destination = "/music"
        read_only   = true
      }

      env {
        POLARIS_PORT      = NOMAD_PORT_http
        POLARIS_CACHE_DIR = "${NOMAD_ALLOC_DIR}/data"
      }

      config {
        image = "ogarcia/polaris:${var.version}"

        ports = [
          "http",
        ]
      }

      resources {
        cpu        = 100
        memory     = 64
        memory_max = 128
      }
    }
  }
}
