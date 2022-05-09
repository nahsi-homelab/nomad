variables {
  versions = {
    filerun = "latest"
  }
}

job "filerun" {
  datacenters = ["syria"]
  namespace   = "services"

  group "filerun" {
    network {
      port "http" {
        to = 80
      }
    }

    service {
      name = "filerun"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.filerun.entrypoints=public",
        "traefik.http.routers.filerun.rule=Host(`filerun.nahsi.dev`)",
      ]
    }

    volume "filerun" {
      type   = "host"
      source = "filerun"
    }

    volume "nahsi" {
      type   = "host"
      source = "storage-nahsi"
    }

    volume "taisto" {
      type   = "host"
      source = "storage-taisto"
    }

    task "filerun" {
      driver = "docker"

      vault {
        policies = ["filerun"]
      }

      env {
        APACHE_RUN_USER     = "www-data"
        APACHE_RUN_USER_ID  = "33"
        APACHE_RUN_GROUP    = "www-data"
        APACHE_RUN_GROUP_ID = "33"
      }

      volume_mount {
        volume      = "filerun"
        destination = "/var/www/html"
      }

      volume_mount {
        volume      = "nahsi"
        destination = "/users/nahsi"
      }

      volume_mount {
        volume      = "taisto"
        destination = "/users/taisto"
      }

      config {
        image = "filerun/filerun:${var.versions.filerun}"
        ports = ["http"]

        volumes = [
          "local/settings.ini:/usr/local/etc/php/conf.d/filerun-optimization.ini:ro",
        ]
      }

      template {
        data = <<-EOH
        {{ with secret "mariadb/static-creds/filerun" }}
        FR_DB_USER='{{ .Data.username }}'
        FR_DB_PASS='{{ .Data.password }}'
        {{- end }}
        FR_DB_HOST='mariadb.service.consul'
        FR_DB_PORT=3106
        FR_DB_NAME='filerun'
        EOH

        destination = "secrets/db.env"
        env         = true
      }

      template {
        data        = file("settings.ini")
        destination = "local/settings.ini"
      }

      resources {
        cpu        = 500
        memory     = 256
        memory_max = 512
      }
    }
  }
}
