variables {
  version = "10.7.7"
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
        "traefik.http.routers.jellyfin.rule=Host(`jellyfin.service.consul`)",
        "traefik.http.routers.jellyfin.tls=true",
        "ingress.enable=true",
        "ingress.http.routers.jellyfin.rule=Host(`jellyfin.nahsi.dev`)",
        "ingress.http.routers.jellyfin.tls=true"
      ]

      check {
        type     = "http"
        protocol = "http"
        path     = "/health"
        port     = "http"
        interval = "20s"
        timeout  = "2s"
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
        cpu    = 10000
        memory = 2048
      }
    }
  }
}
