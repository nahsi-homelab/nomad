variables {
  versions = {
    navidrome = "0.47.5"
  }
}

job "navidrome" {
  datacenters = ["syria"]
  namespace   = "services"

  group "navidrome" {
    network {
      port "http" {}
    }

    volume "navidrome" {
      type   = "host"
      source = "navidrome"
    }

    volume "music" {
      type      = "host"
      source    = "music-nahsi"
      read_only = true
    }

    service {
      name = "navidrome"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.navidrome.entrypoints=public",
        "traefik.http.routers.navidrome.rule=Host(`navidrome.nahsi.dev`)",
      ]
    }

    task "navidrome" {
      driver = "docker"
      user   = "nobody"

      vault {
        policies = ["navidrome"]
      }

      volume_mount {
        volume      = "navidrome"
        destination = "/data"
      }

      volume_mount {
        volume      = "music"
        destination = "/music"
        read_only   = true
      }

      env {
        ND_PORT                    = NOMAD_PORT_http
        ND_ENABLETRANSCODINGCONFIG = true
        ND_SCANSCHEDULE            = "1h"
      }

      config {
        image = "deluan/navidrome:${var.versions.navidrome}"

        ports = [
          "http",
        ]
      }

      template {
        data = <<-EOF
        {{- with secret "secret/navidrome/lastfm" }}
        ND_LASTFM_ENABLED=true
        ND_LASTFM_APIKEY={{ .Data.data.apikey }}
        ND_LASTFM_SECRET={{ .Data.data.secret }}
        {{- end }}
        EOF

        destination = "secrets/lastfm.env"
        env         = true
      }

      resources {
        cpu        = 100
        memory     = 128
        memory_max = 256
      }
    }
  }
}
