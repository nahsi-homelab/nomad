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

    volume "video-nahsi" {
      type   = "host"
      source = "video-nahsi"
    }

    volume "taisto" {
      type   = "host"
      source = "storage-taisto"
    }

    volume "taisto" {
      type   = "host"
      source = "storage-taisto"
    }

    volume "video-taisto" {
      type   = "host"
      source = "video-taisto"
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
        volume      = "video-nahsi"
        destination = "/users/nahsi/video"
        read_only   = true
      }

      volume_mount {
        volume      = "taisto"
        destination = "/users/taisto"
      }

      volume_mount {
        volume      = "video-taisto"
        destination = "/users/taisto/video"
      }

      config {
        image = "filerun/filerun:${var.versions.filerun}"
        ports = ["http"]

        volumes = [
          "local/settings.ini:/usr/local/etc/php/conf.d/filerun-optimization.ini:ro",
          "secrets/db.php:/var/lib/filerun/system/data/autoconfig.php:ro",
        ]
      }

      template {
        data        = file("settings.ini")
        destination = "local/settings.ini"
      }

      template {
        data        = file("db.php")
        destination = "secrets/db.php"
      }

      resources {
        cpu        = 500
        memory     = 256
        memory_max = 512
      }
    }
  }
}
