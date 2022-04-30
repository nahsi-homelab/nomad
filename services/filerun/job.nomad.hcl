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
        "ingress.enable=true",
        "ingress.http.routers.filerun.entrypoints=https",
        "ingress.http.routers.filerun.rule=Host(`filerun.nahsi.dev`)",
      ]
    }

    volume "filerun" {
      type            = "csi"
      source          = "filerun"
      attachment_mode = "file-system"
      access_mode     = "single-node-writer"
    }

    volume "nahsi" {
      type            = "csi"
      source          = "filerun-nahsi"
      attachment_mode = "file-system"
      access_mode     = "single-node-writer"
    }

    volume "taisto" {
      type            = "csi"
      source          = "filerun-taisto"
      attachment_mode = "file-system"
      access_mode     = "single-node-writer"
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
      }

      template {
        data = <<-EOH
        {{ with secret "mariadb/static-creds/filerun" }}
        FR_DB_USER='{{ .Data.username }}'
        FR_DB_PASS='{{ .Data.password }}'
        {{- end }}
        FR_DB_HOST=mariadb.service.consul
        FR_DB_PORT=3306
        FR_DB_NAME=filerun
        EOH

        destination = "secrets/db.env"
        env         = true
      }

      resources {
        cpu    = 500
        memory = 256
      }
    }
  }
}
