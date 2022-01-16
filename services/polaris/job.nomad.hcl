variables {
  version = "0.13.5"
}

job "polaris" {
  datacenters = ["syria"]
  namespace   = "services"

  constraint {
    attribute = attr.unique.hostname
    value     = "antiochia"
  }

  group "polaris" {
    network {
      port "http" {}
    }

    service {
      name = "polaris"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.polaris.entrypoints=https",
        "traefik.http.routers.polaris.rule=Host(`polaris.service.consul`)",
        "traefik.http.routers.polaris.tls=true"
      ]
    }

    task "polaris" {
      driver = "docker"

      env {
        POLARIS_PORT = "${NOMAD_PORT_http}"
      }

      config {
        image = "ogarcia/polaris:${var.version}"

        ports = [
          "http"
        ]

        volumes = [
          "/home/nahsi/media/music/:/music:ro",
          "/mnt/apps/polaris/cache:/var/cache/polaris",
          "/mnt/apps/polaris/data:/var/lib/polaris",
        ]
      }

      resources {
        cpu    = 100
        memory = 300
      }
    }
  }
}
