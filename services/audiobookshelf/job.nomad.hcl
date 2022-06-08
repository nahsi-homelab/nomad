variables {
  versions = {
    audiobookshelf = "2.0.20"
  }
}

job "audiobookshelf" {
  datacenters = ["syria"]
  namespace   = "services"

  group "audiobookshelf" {
    network {
      port "http" {
        to = 80
      }
    }

    service {
      name = "audiobookshelf"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.audiobookshelf.entrypoints=public",
        "traefik.http.routers.audiobookshelf.rule=Host(`audio.nahsi.dev`)",
      ]
    }

    volume "config" {
      type   = "host"
      source = "audiobookshelf-config"
    }

    volume "metadata" {
      type   = "host"
      source = "audiobookshelf-metadata"
    }

    volume "audiobooks-nahsi" {
      type   = "host"
      source = "audiobooks-nahsi"
    }

    volume "podcasts-nahsi" {
      type   = "host"
      source = "podcasts-nahsi"
    }

    task "audiobookshelf" {
      driver = "docker"

      volume_mount {
        volume      = "config"
        destination = "/config"
      }

      volume_mount {
        volume      = "metadata"
        destination = "/metadata"
      }

      volume_mount {
        volume      = "audiobooks-nahsi"
        destination = "/users/nahsi/audiobooks"
      }

      volume_mount {
        volume      = "podcasts-nahsi"
        destination = "/users/nahsi/podcasts"
      }

      config {
        image = "ghcr.io/advplyr/audiobookshelf:${var.versions.audiobookshelf}"
        ports = ["http"]
      }

      resources {
        cpu        = 5000
        memory     = 128
        memory_max = 256
      }
    }
  }
}
