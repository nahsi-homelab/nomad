variables {
  version = "10.7.7"
}

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
      name = "jellyfin-app"
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
      user = "nobody"

      volume_mount {
        volume = "jellyfin"
        destination = "/config"
      }

      volume_mount {
        volume = "jellyfin-cache"
        destination = "/cache"
      }

      config {
        image = "jellyfin/jellyfin:${var.version}-${attr.cpu.arch}"

        ports = [
          "http"
        ]

        volumes = [
          "/home/nahsi/media/video:/video:ro",
          "/home/nahsi/media/audio/audiobooks:/audiobooks:ro",
          "/home/nahsi/media/podcasts:/podcasts:ro"
        ]
      }

      resources {
        cpu = 10000
        memory = 2048
      }
    }
  }
}
