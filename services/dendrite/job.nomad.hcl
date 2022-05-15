variables {
  versions = {
    dendrite = "0.8.5"
  }
}

job "dendrite" {
  datacenters = [
    "syria",
  ]
  namespace = "services"

  vault {
    policies = ["dendrite"]
  }

  group "monolith" {
    network {
      port "http" {}
    }

    service {
      name = "dendrite"
      port = "http"

      meta {
        alloc_id = NOMAD_ALLOC_ID
      }

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.dendrite.entrypoints=public",
        "traefik.http.routers.dendrite.rule=Host(`matrix.nahsi.dev`)",
      ]

      check {
        name     = "Dendrite HTTP"
        port     = "http"
        type     = "http"
        path     = "/_dendrite/monitor/health"
        interval = "10s"
        timeout  = "1s"
      }
    }

    volume "media" {
      type   = "host"
      source = "dendrite-media"
    }

    task "monolith" {
      driver = "docker"
      user   = "nobody"

      volume_mount {
        volume      = "media"
        destination = "/media"
      }

      config {
        image = "matrixdotorg/dendrite-monolith:v${var.versions.dendrite}"
        ports = [
          "http",
        ]

        args = [
          "-config=/secrets/dendrite.yml",
          "-http-bind-address=0.0.0.0:${NOMAD_PORT_http}",
        ]
      }

      template {
        data        = file("dendrite.yml")
        destination = "secrets/dendrite.yml"
      }

      template {
        data = <<-EOH
        {{- with secret "secret/dendrite/matrix-key" -}}
        {{ .Data.data.private_key }}
        {{- end -}}
        EOH

        destination = "secrets/keys/matrix.pem"
      }

      resources {
        cpu        = 500
        memory     = 256
        memory_max = 1024
      }
    }
  }
}
