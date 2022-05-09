variables {
  versions = {
    calibre_web = "version-0.6.18"
  }
}

job "calibre" {
  datacenters = ["asia"]
  namespace   = "services"

  group "calibre-web" {
    network {
      port "http" {
        to = 8083
      }
    }

    service {
      name = "calibre-web"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.calibre-web.entrypoints=public",
        "traefik.http.routers.calibre-web.rule=Host(`calibre.nahsi.dev`)",
      ]

      check {
        name     = "calibre-web"
        type     = "tcp"
        port     = "http"
        interval = "20s"
        timeout  = "1s"
      }
    }

    volume "calibre-web" {
      type   = "host"
      source = "calibre-web"
    }

    volume "calibre" {
      type   = "host"
      source = "calibre"
    }

    task "calibre-web" {
      driver = "docker"

      env {
        PUID        = "1000"
        PGID        = "1000"
        TZ          = "Europe/Moscow"
        DOCKER_MODS = "linuxserver/calibre-web:calibre"
      }

      volume_mount {
        volume      = "calibre-web"
        destination = "/config"
      }

      volume_mount {
        volume      = "calibre"
        destination = "/books"
      }

      config {
        image      = "lscr.io/linuxserver/calibre-web:${var.versions.calibre_web}"
        force_pull = true

        ports = [
          "http",
        ]
      }

      resources {
        cpu        = 100
        memory     = 256
        memory_max = 1024
      }
    }
  }
}
