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
        path = "/health"
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

        volumes = [
          "/mnt/apps/jellyfin/config:/config",
          "/mnt/apps/jellyfin/cache:/cache",
          "/home/nahsi/media/video:/video"
        ]
      }

      resources {
        cpu = 60000
        memory = 4096
      }
    }
  }
}
