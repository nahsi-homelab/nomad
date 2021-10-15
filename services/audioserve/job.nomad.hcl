job "audioserve" {
  datacenters = ["syria"]
  type        = "service"

  group "audioserve" {
    network {
      port "http" {
        to = 3000
      }
    }

    service {
      name = "audioserve"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.audioserve.tls=true"
      ]
    }

    task "audioserve" {
      driver = "docker"

      config {
        image = "izderadicka/audioserve"

        args = [
          "--no-authentication",
          "/audiobooks",
          "/podcasts"
        ]

        ports = [
          "http"
        ]

        volumes = [
          "/home/nahsi/media/audio/audiobooks:/audiobooks:ro",
          "/home/nahsi/media/audio/podcasts:/podcasts:ro",
        ]
      }

      resources {
        cpu = 100
        memory = 300
      }
    }
  }
}
