variables {
  versions = {
    home-assistant = "2021.12.10"
  }
}

job "home-assistant" {
  datacenters = [
    "asia",
  ]
  namespace = "services"

  group "home-assistant" {
    ephemeral_disk {
      sticky  = true
      migrate = true
    }

    network {
      port "http" {}
    }

    volume "home-assistant" {
      type   = "host"
      source = "home-assistant"
    }

    task "home-assistant" {
      driver = "docker"

      vault {
        policies = ["home-assistant"]
      }

      resources {
        cpu    = 300
        memory = 256
      }

      service {
        name = "home-assistant"
        port = "http"

        tags = [
          "traefik.enable=true",
          "traefik.entrypoints=https",
          "traefik.http.routers.ha.rule=Host(`home-assistant.service.consul`)",
        ]
      }

      volume_mount {
        volume      = "home-assistant"
        destination = "/config"
      }

      env {
        TZ   = "Europe/Moscow"
        PUID = "1000"
        PGID = "1000"
      }

      kill_timeout = "10s"

      config {
        image = "nahsihub/home-assistant:${var.versions.home-assistant}"
        ports = ["http"]
        volumes = [
          "local/configuration.yaml:/config/configuration.yaml",
          "local/custom_components/:/config/custom_components/",
        ]
      }

      artifact {
        source      = "git::https://github.com/sbidy/wiz_light//custom_components/wiz_light"
        destination = "local/custom_components/wiz_light"
      }

      template {
        data            = file("configuration.yaml")
        destination     = "local/configuration.yaml"
        left_delimiter  = "[["
        right_delimiter = "]]"
      }

      template {
        data = <<-EOH
        {{ with secret "secret/home-assistant/location" -}}
        LATITUDE={{ .Data.data.latitude }}
        LONGITUDE={{ .Data.data.longitude }}
        ELEVATION={{ .Data.data.elevation }}
        {{- end }}

        {{ with secret "secret/home-assistant/spotify" -}}
        SPOTIFY_CLIENT_ID={{ .Data.data.client_id }}
        SPOTIFY_CLIENT_SECRET={{ .Data.data.client_secret }}
        {{- end }}
        EOH

        destination = "secrets/secrets.env"
        env         = true
      }

      template {
        data = <<-EOH
        db_url: postgresql://home-assistant:{{- with secret "postgres/static-creds/home-assistant" -}}{{ .Data.password }}{{ end -}}@master.postgres.service.consul/home-assistant
        EOH

        destination = "secrets/recorder.yml"
      }
    }
  }
}
