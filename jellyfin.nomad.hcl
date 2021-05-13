# vim: set ft=hcl sw=2 ts=2 :
job "jellyfin" {

  datacenters = ["syria"]

  type        = "service"

  group "jellyfin" {

    network {
      port "http" {
        static = 8096
        to = 8096
      }
    }

    service {
      name = "jellyfin"
      port = "http"

      check {
        type = "http"
        protocol = "http"
        path = "/jellyfin/health"
        port = "http"
        interval = "10s"
        timeout = "2s"
      }
    }

    task "jellyfin" {
      driver = "docker"

      config {
        image = "jellyfin/jellyfin:10.7.2-amd64"

        ports = [
          "http"
        ]

        mount {
          type = "tmpfs"
          target = "/config/transcodes"
          readonly = false
          tmpfs_options {
            size = 4000000
          }
        }

        volumes = [
          "/mnt/apps/jellyfin/config:/config",
          "/mnt/apps/jellyfin/cache:/cache",
          "/home/nahsi/media/video:/video:ro",
          "/home/nahsi/media/audio/audiobooks:/audiobooks:ro",
          "/home/nahsi/media/audio/podcasts:/podcasts:ro"
        ]
      }

      resources {
        cpu = 30000
        memory = 4096
      }
    }
  }
}
