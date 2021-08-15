job "transmission" {

  datacenters = ["syria"]
  type        = "service"

  group "transmission" {
    network {
      port "web-ui" {
        static = 9091
        to = 9091
      }

      port "torrent" {
        static = 51413
        to = 51413
      }
    }

    service {
      name = "transmission"
      port = "web-ui"
    }

    volume "transmission" {
      type = "host"
      source = "transmission"
    }

    task "transmission" {
      driver = "docker"

      env {
        PUID = "1000"
        PGID = "1000"
        TZ = "Europe/Moscow"
        TRANSMISSION_WEB_HOME="/flood-for-transmission"
      }

      volume_mount {
        volume = "transmission"
        destination = "/config"
      }

      config {
        image = "linuxserver/transmission:latest"

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
