job "audioserve" {
  datacenters = ["syria"]
  namespace   = "services"

  constraint {
    attribute = attr.unique.hostname
    value     = "antiochia"
  }

  group "audioserve" {
    ephemeral_disk {
      sticky = true
    }
    network {
      port "http" {
        to = 3000
      }
    }

    service {
      name = "audioserve"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.audioserve.entrypoints=https",
        "traefik.http.routers.audioserve.rule=Host(`audioserve.service.consul`)",
        "ingress.enable=true",
        "ingress.http.routers.audioserve.entrypoints=https",
        "ingress.http.routers.audioserve.rule=Host(`audioserve.nahsi.dev`)",
      ]
    }

    task "audioserve" {
      driver = "docker"

      vault {
        policies = ["audioserve"]
      }

      config {
        image = "izderadicka/audioserve"

        args = [
          "--data-dir=/alloc/data/",
          "/audiobooks",
          "/podcasts"
        ]

        ports = [
          "http"
        ]

        volumes = [
          "/home/nahsi/media/audio/audiobooks:/audiobooks:ro",
          "/home/nahsi/media/audio/podcasts:/podcasts:ro",
        ]
      }

      template {
        data = <<-EOH
        AUDIOSERVE_SHARED_SECRET={{ with secret "secret/audioserve/nahsi" }}{{ .Data.data.secret }}{{ end }}
        EOH

        destination = "secrets/audioserve.env"
        env         = true
      }

      resources {
        cpu    = 100
        memory = 300
      }
    }
  }
}
