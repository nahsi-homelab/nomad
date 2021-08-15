job "jellyfin" {

  datacenters = ["syria"]
  type        = "service"

  group "jellyfin" {

    network {
      port "http" {
        to = 8096
      }
    }

    service {
      name = "jellyfin"
      port = "http"

      check {
        type = "http"
        protocol = "http"
        path = "/health"
        port = "http"
        interval = "20s"
        timeout = "2s"
      }
    }

    volume "jellyfin" {
      type = "host"
      source = "jellyfin"
    }

    volume "jellyfin-cache" {
      type = "host"
      source = "jellyfin-cache"
    }

    task "jellyfin" {
      driver = "docker"

      volume_mount {
        volume = "jellyfin"
        destination = "/config"
      }

      volume_mount {
        volume = "jellyfin-cache"
        destination = "/cache"
      }

      config {
        image = "jellyfin/jellyfin:10.7.6-${attr.cpu.arch}"

        ports = [
          "http"
        ]

        volumes = [
          "/home/nahsi/media/video:/video:ro",
          "/home/nahsi/media/audio/audiobooks:/audiobooks:ro",
          "/home/nahsi/media/audio/podcasts:/podcasts:ro"
        ]
      }

      resources {
        cpu = 10000
        memory = 256
      }
    }
  }
}
