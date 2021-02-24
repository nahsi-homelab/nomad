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
      driver = "podman"

      config {
        image = "docker://jellyfin/jellyfin:10.7.0-rc3-amd64"

        ports = [
          "http"
        ]

        tmpfs = [
          "/config/transcodes:size=4G"
        ]

        volumes = [
          "/mnt/apps/jellyfin/config:/config",
          "/mnt/apps/jellyfin/cache:/cache",
          "/home/nahsi/media/video:/video:ro"
        ]
      }

      resources {
        cpu = 30000
        memory = 4096
      }
    }
  }
}
