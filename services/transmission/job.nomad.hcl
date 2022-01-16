job "transmission" {
  datacenters = ["syria"]
  namespace   = "services"

  group "transmission" {
    network {
      port "web-ui" {
        static = 9091
        to     = 9091
      }

      port "torrent" {
        static = 51413
        to     = 51413
      }
    }

    service {
      name = "transmission"
      port = "web-ui"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.transmission.entrypoints=https",
        "traefik.http.routers.transmission.rule=Host(`transmission.service.consul`)",
        "traefik.http.routers.transmission.tls=true"
      ]
    }

    volume "transmission" {
      type   = "host"
      source = "transmission"
    }

    task "transmission" {
      driver = "docker"

      env {
        PUID                  = "1000"
        PGID                  = "1000"
        TZ                    = "Europe/Moscow"
        TRANSMISSION_WEB_HOME = "/flood-for-transmission"
      }

      volume_mount {
        volume      = "transmission"
        destination = "/config"
      }

      config {
        image = "linuxserver/transmission"

        ports = [
          "web-ui",
          "torrent"
        ]

        volumes = [
          "/home/nahsi/downloads:/downloads",
          "/home/nahsi/media:/media"
        ]
      }

      resources {
        memory = 128
      }
    }
  }
}
