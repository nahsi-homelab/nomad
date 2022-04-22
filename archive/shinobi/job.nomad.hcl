variables {
  versions = {
    shinobi = "dev"
  }
}

job "shinobi" {
  datacenters = ["syria"]
  namespace   = "services"

  group "shinobi" {
    network {
      port "http" {
        to = 8080
      }
      port "smtp" {
        to     = 1338
        static = 1338
      }
    }

    service {
      name = "shinobi"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.shinobi.entrypoints=https",
        "traefik.http.routers.shinobi.rule=Host(`shinobi.service.consul`)",
      ]
    }

    volume "shinobi" {
      type   = "host"
      source = "shinobi"
    }

    task "shinobi" {
      driver = "docker"

      vault {
        policies = ["shinobi"]
      }

      resources {
        cpu    = 4000
        memory = 1024
      }

      volume_mount {
        volume      = "shinobi"
        destination = "/home/Shinobi/videos"
      }

      env {
        DB_DISABLE_INCLUDED = true
      }

      config {
        shm_size = "2000000000"
        image    = "shinobisystems/shinobi:${var.versions.shinobi}"

        ports = [
          "http",
          "smtp",
        ]

        volumes = [
          "secrets/configs:/config",
          "alloc/data/plugins:/home/Shinobi/plugins",
        ]
      }

      dynamic "template" {
        for_each = fileset(".", "configs/**")

        content {
          data        = file(template.value)
          destination = "secrets/${template.value}"
        }
      }

      template {
        data        = <<-EOH
        DB_HOST=mariadb.service.consul
        DB_USER=shinobi
        DB_PASSWORD='{{ with secret "mariadb/static-creds/shinobi" }}{{ .Data.password }}{{ end }}'
        DB_DATABASE=ccio
        EOH
        destination = "secrets/db.env"
        env         = true
      }
    }
  }
}
