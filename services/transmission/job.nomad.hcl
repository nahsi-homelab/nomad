variables {
  versions = {
    transmission = "version-3.00-r5"
  }
}
job "transmission" {
  datacenters = ["syria"]
  namespace   = "services"

  vault {
    policies = [
      "transmission",
    ]
  }

  group "transmission-nahsi" {
    network {
      port "web-ui" {
        to = 9091
      }

      port "peer" {
        static = 51413
        to     = 51413
      }
    }

    service {
      name = "transmission"
      port = "web-ui"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.transmission-nahsi.entrypoints=https",
        "traefik.http.routers.transmission-nahsi.rule=Host(`transmission.service.consul`)",
      ]
    }

    volume "transmission" {
      type   = "host"
      source = "transmission-nahsi"
    }

    volume "video" {
      type   = "host"
      source = "video-nahsi"
    }

    volume "audio" {
      type   = "host"
      source = "audio-nahsi"
    }

    volume "downloads" {
      type   = "host"
      source = "downloads-nahsi"
    }

    task "transmission" {
      driver = "docker"

      env {
        PUID                  = "1000"
        PGID                  = "1000"
        TZ                    = "Europe/Moscow"
        TRANSMISSION_WEB_HOME = "/transmissionic"
        PEERPORT              = NOMAD_PORT_peer
      }

      volume_mount {
        volume      = "transmission"
        destination = "/config"
      }

      volume_mount {
        volume      = "video"
        destination = "/media/video"
      }

      volume_mount {
        volume      = "audio"
        destination = "/media/audio"
      }

      volume_mount {
        volume      = "downloads"
        destination = "/downloads"
      }

      config {
        image      = "linuxserver/transmission:${var.versions.transmission}"
        force_pull = true

        ports = [
          "web-ui",
          "peer",
        ]
      }

      resources {
        cpu        = 100
        memory     = 64
        memory_max = 128
      }
    }
  }

  group "transmission-taisto" {
    network {
      port "web-ui" {
        to = 9091
      }

      port "peer" {
        static = 51414
        to     = 51414
      }
    }

    service {
      name = "transmission-taisto"
      port = "web-ui"

      tags = [
        "ingress.enable=true",
        "ingress.http.routers.transmission-taisto.entrypoints=https",
        "ingress.http.routers.transmission-taisto.rule=Host(`transmission-taisto.nahsi.dev`)",
      ]
    }

    volume "transmission" {
      type   = "host"
      source = "transmission-taisto"
    }

    volume "video" {
      type   = "host"
      source = "video-taisto"
    }

    volume "downloads" {
      type   = "host"
      source = "downloads-taisto"
    }

    task "transmission" {
      driver = "docker"

      env {
        PUID                  = "1001"
        PGID                  = "1001"
        TZ                    = "Europe/Moscow"
        TRANSMISSION_WEB_HOME = "/transmissionic"
        PEERPORT              = NOMAD_PORT_peer
      }

      volume_mount {
        volume      = "transmission"
        destination = "/config"
      }

      volume_mount {
        volume      = "video"
        destination = "/media/video"
      }

      volume_mount {
        volume      = "downloads"
        destination = "/downloads"
      }

      config {
        image      = "linuxserver/transmission:${var.versions.transmission}"
        force_pull = true

        ports = [
          "web-ui",
          "peer",
        ]
      }

      template {
        data = <<-EOH
        {{ with secret "secret/transmission/taisto" }}
        USER='{{ .Data.data.username }}'
        PASS='{{ .Data.data.password }}'
        {{- end }}
        EOH

        destination = "secrets/user.env"
        env         = true
      }

      resources {
        cpu        = 100
        memory     = 64
        memory_max = 128
      }
    }
  }
}
