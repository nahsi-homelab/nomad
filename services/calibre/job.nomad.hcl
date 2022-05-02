variables {
  versions = {
    calibre     = "version-v5.41.0"
    calibre_web = "version-0.6.18"
  }
}

job "calibre" {
  datacenters = ["syria"]
  namespace   = "services"

  group "calibre" {
    network {
      port "guacamole" {
        to = 8080
      }
      port "http" {
        to = 8081
      }
    }

    volume "calibre" {
      type            = "csi"
      source          = "calibre"
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    task "calibre" {
      driver = "docker"

      vault {
        policies = [
          "calibre",
        ]
      }

      env {
        PUID = "1050"
        PGID = "1050"
        TZ   = "Europe/Moscow"
      }

      volume_mount {
        volume      = "calibre"
        destination = "/config"
      }

      config {
        image      = "lscr.io/linuxserver/calibre:${var.versions.calibre}"
        force_pull = true

        ports = [
          "guacamole",
          "http",
        ]
      }

      template {
        data = <<-EOH
        {{ with secret "secret/calibre/guacamole" }}
        PASSWORD='{{ .Data.data.password }}'
        {{- end }}
        EOH

        destination = "secrets/secret.env"
        env         = true
      }

      resources {
        cpu        = 500
        memory     = 256
        memory_max = 1024
      }
    }
  }

  group "calibre-web" {
    network {
      port "http" {
        to = 8083
      }
    }

    service {
      name = "calibre-web"
      port = "http"

      tags = [
        "ingress.enable=true",
        "ingress.http.routers.calibre-web.entrypoints=https",
        "ingress.http.routers.calibre-web.rule=Host(`calibre.nahsi.dev`)",

        "traefik.enable=true",
        "traefik.http.routers.calibre-web.entrypoints=https",
        "traefik.http.routers.calibre-web.rule=Host(`calibre-web.service.consul`)",
      ]

      check {
        name     = "SeaweedFS master"
        type     = "tcp"
        port     = "http"
        interval = "20s"
        timeout  = "1s"
      }
    }

    volume "calibre-web" {
      type            = "csi"
      source          = "calibre-web"
      attachment_mode = "file-system"
      access_mode     = "single-node-writer"
    }

    volume "calibre" {
      type            = "csi"
      source          = "calibre"
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    task "calibre-web" {
      driver = "docker"

      env {
        PUID        = "1050"
        PGID        = "1050"
        TZ          = "Europe/Moscow"
        DOCKER_MODS = "linuxserver/calibre-web:calibre"
      }

      volume_mount {
        volume      = "calibre-web"
        destination = "/config"
      }

      volume_mount {
        volume      = "calibre"
        destination = "/books"
      }

      config {
        image      = "lscr.io/linuxserver/calibre-web:${var.versions.calibre_web}"
        force_pull = true

        ports = [
          "http",
        ]
      }

      resources {
        cpu        = 100
        memory     = 256
        memory_max = 1024
      }
    }
  }
}
