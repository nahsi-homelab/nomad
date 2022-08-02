variables {
  version = "10.8.3"
}

job "jellyfin" {
  datacenters = ["syria"]
  namespace   = "services"

  group "jellyfin" {

    network {
      port "http" {
        to = 8096
      }
    }

    service {
      name = "jellyfin"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.jellyfin.entrypoints=https",
        "traefik.http.routers.jellyfin.rule=Host(`jellyfin.service.consul`)",

        "traefik.http.routers.jellyfin-pub.entrypoints=public",
        "traefik.http.routers.jellyfin-pub.rule=Host(`jellyfin.nahsi.dev`)",
      ]

      check {
        name     = "Jellyfin HTTP"
        type     = "http"
        protocol = "http"
        path     = "/health"
        port     = "http"
        interval = "20s"
        timeout  = "1s"
      }
    }

    volume "jellyfin" {
      type   = "host"
      source = "jellyfin"
    }

    volume "jellyfin-cache" {
      type   = "host"
      source = "jellyfin-cache"
    }

    volume "video-nahsi" {
      type      = "host"
      source    = "video-nahsi"
      read_only = true
    }

    volume "video-taisto" {
      type      = "host"
      source    = "video-taisto"
      read_only = true
    }

    task "jellyfin" {
      driver = "docker"
      user   = "nobody"

      volume_mount {
        volume      = "jellyfin"
        destination = "/config"
      }

      volume_mount {
        volume      = "jellyfin-cache"
        destination = "/cache"
      }

      volume_mount {
        volume      = "video-nahsi"
        destination = "/video"
        read_only   = true
      }

      volume_mount {
        volume      = "video-taisto"
        destination = "/taisto/video"
        read_only   = true
      }

      config {
        image = "jellyfin/jellyfin:${var.version}"

        ports = [
          "http",
        ]
      }

      resources {
        cpu        = 10000
        memory     = 2048
        memory_max = 4096
      }
    }
  }
}
