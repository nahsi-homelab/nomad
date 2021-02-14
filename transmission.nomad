# vim: set ft=hcl sw=2 ts=2 :
job "transmission" {

  datacenters = ["syria"]

  type        = "service"

  group "transmission" {
    network {
      port "web-ui" {
        static = 9091
        to = 9091
      }

      port "peer" {
        static = 51413
        to = 51413
      }
    }

    service {
      name = "transmission"
      port = "web-ui"
    }

    task "transmission" {
      driver = "podman"

      env {
        PUID = "1000"
        PGID = "1000"
        TZ = "Europe/Moscow"
      }

      config {
        image = "docker://linuxserver/transmission:version-3.00-r2"

        ports = [
          "web-ui",
          "peer"
        ]

        volumes = [
          "/mnt/apps/transmission/:/config",
          "/home/nahsi/watch:/watch",
          "/home/nahsi/downloads:/downloads",
          "/home/nahsi/media:/media"
        ]
      }

      resources {
        cpu = "1000"
        memory = 512
      }
    }
  }
}
