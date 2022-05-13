variables {
  versions = {
    audiobookshelf = "2.0.13"
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
        cpu        = 200
        memory     = 128
        memory_max = 256
      }
    }
  }
}
