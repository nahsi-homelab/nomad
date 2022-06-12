variables {
  versions = {
    dendrite          = "0.8.8"
    matrix-media-repo = "1.2.12"
  }
}

job "dendrite" {
  datacenters = [
    "syria",
  ]
  namespace = "services"

  group "dendrite" {
    vault {
      policies = ["dendrite"]
    }

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
        "traefik.http.routers.dendrite.rule=Host(`nahsi.dev`) && PathPrefix(`/_matrix`)",

        "traefik.http.middlewares.dendrite-cors.headers.accesscontrolalloworiginlist=*",
        "traefik.http.middlewares.dendrite-cors.headers.accesscontrolallowheaders=X-Requested-With,Content-Type,Authorization",
        "traefik.http.middlewares.dendrite-cors.headers.accesscontrolallowmethods=GET,POST,DELETE,OPTIONS,PUT",
        "traefik.http.middlewares.dendrite-cors.headers.addvaryheader=true",

        "traefik.http.routers.dendrite.middlewares=dendrite-cors@consulcatalog",
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

    task "dendrite" {
      driver = "docker"
      user   = "nobody"

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
        cpu        = 3000
        memory     = 400
        memory_max = 2048
      }
    }
  }

  group "matrix-media-repo" {
    vault {
      policies = ["matrix-media-repo"]
    }

    network {
      port "http" {}
      port "metrics" {}
    }

    service {
      name = "matrix-media-repo"
      port = "http"

      meta {
        alloc_id = NOMAD_ALLOC_ID
        metrics  = NOMAD_ADDR_metrics
      }

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.matrix-media-repo.entrypoints=public",
        "traefik.http.routers.matrix-media-repo.rule=Host(`nahsi.dev`) && PathPrefix(`/_matrix/media`)",
      ]

      check {
        name     = "matrix-media-repo HTTP"
        port     = "http"
        type     = "http"
        path     = "/healthz"
        interval = "10s"
        timeout  = "1s"
      }
    }

    task "matrix-media-repo" {
      driver = "docker"
      user   = "nobody"

      config {
        image = "turt2live/matrix-media-repo:v${var.versions.matrix-media-repo}"

        ports = [
          "http",
          "metrics",
        ]

        command = "media_repo"

        volumes = [
          "secrets/media-repo.yaml:/data/media-repo.yaml:ro",
        ]
      }

      template {
        data        = file("matrix-media-repo.yml")
        destination = "secrets/media-repo.yaml"
      }

      resources {
        cpu        = 500
        memory     = 150
        memory_max = 512
      }
    }
  }
}
