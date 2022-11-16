variables {
  versions = {
    photoprism = "221116-jammy"
  }
}

job "photoprism" {
  datacenters = ["syria"]
  namespace   = "services"

  group "photoprism" {
    network {
      port "http" {
        to = 2342
      }
    }

    service {
      name = "photoprism"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.photoprism.entrypoints=public",
        "traefik.http.routers.photoprism.rule=Host(`photo.nahsi.dev`)",
      ]
    }

    volume "photoprism-storage" {
      type   = "host"
      source = "photoprism-storage"
    }

    volume "photoprism-originals" {
      type   = "host"
      source = "photoprism-originals"
    }

    task "photoprism" {
      driver = "docker"
      user   = "1200"

      vault {
        policies = ["photoprism"]
      }

      env {
        PHOTOPRISM_AUTH_MODE        = "password"
        PHOTOPRISM_SITE_URL         = "https://photo.nahsi.dev"
        PHOTOPRISM_ORIGINALS_LIMIT  = 5000
        PHOTOPRISM_HTTP_COMPRESSION = "gzip"
        PHOTOPRISM_LOG_LEVEL        = "info"
        PHOTOPRISM_READONLY         = "false"
        PHOTOPRISM_DISABLE_CHOWN    = "true"
        PHOTOPRISM_DETECT_NSFW      = "true"
        PHOTOPRISM_UPLOAD_NSFW      = "true"

        PHOTOPRISM_SITE_CAPTION     = "Photoprism"
        PHOTOPRISM_SITE_DESCRIPTION = "nahsi photos"
        PHOTOPRISM_SITE_AUTHOR      = "nahsi"

        PHOTOPRISM_UID       = 1200
        PHOTOPRISM_GID       = 1200
        PHOTOPRISM_TEMP_PATH = "/alloc/tmp"

        PHOTOPRISM_TRUSTED_PROXY = "172.16.0.0/12,10.1.10.0/24"
      }

      volume_mount {
        volume      = "photoprism-storage"
        destination = "/photoprism/storage"
      }

      volume_mount {
        volume      = "photoprism-originals"
        destination = "/photoprism/originals"
      }

      config {
        image = "photoprism/photoprism:${var.versions.photoprism}"
        ports = ["http"]
      }

      template {
        data = <<-EOF
        {{- with secret "secret/photoprism/admin" }}
        PHOTOPRISM_ADMIN_USER={{ .Data.data.username }}
        PHOTOPRISM_ADMIN_PASSWORD={{ .Data.data.password }}
        {{- end }}
        EOF

        destination = "secrets/admin.env"
        env         = true
      }

      template {
        data = <<-EOF
        {{- with secret "mariadb/static-creds/photoprism" }}
        PHOTOPRISM_DATABASE_DIRVER=mysql
        PHOTOPRISM_DATABASE_SERVER=mariadb.service.consul:3106
        PHOTOPRISM_DATABASE_NAME=photoprism
        PHOTOPRISM_DATABASE_USER={{ .Data.username }}
        PHOTOPRISM_DATABASE_PASSWORD={{ .Data.password }}
        {{- end }}
        EOF

        destination = "secrets/db.env"
        env         = true
      }

      resources {
        cpu        = 1000
        memory     = 512
        memory_max = 5000
      }
    }
  }
}
