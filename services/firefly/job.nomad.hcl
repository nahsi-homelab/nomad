variables {
  versions = {
    firefly = "version-5.6.2"
    firefly-csv = "version-2.6.1"
  }
}

job "firefly" {
  datacenters = ["syria"]
  type        = "service"

  group "firefly" {
    network {
      port "firefly" { 
        to = 8080
      }

      port "firefly-csv" {
        to = 8080
      }
    }

    /* volume "firefly" { */
    /*   type = "host" */
    /*   source = "firefly" */
    /* } */

    task "firefly" {
      driver = "docker"

      service {
        name = "firefly"
        port = "firefly"
        address_mode = "host"

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.firefly.rule=Host(`firefly.service.consul`)",
          "traefik.http.routers.firefly.tls=true"
        ]

        check {
          name     = "Firefly HTTP"
          type     = "http"
          path     = "/health"
          interval = "10s"
          timeout  = "2s"
        }
      }

      vault {
        policies = ["firefly"]
      }

      /* volume_mount { */
      /*   volume = "firefly" */
      /*   destination = "/var/www/html/storage/upload" */
      /* } */

      env {
        APP_URL="https://firefly.service.consul"
        TRUSTED_PROXIES="**"
      }

      config {
        image = "fireflyiii/core:${var.versions.firefly}"

        ports = [
          "firefly"
        ]
      }

      template {
        data =<<EOH
        DB_HOST="master.postgres.service.consul"
        DB_PORT="5432"
        DB_CONNECTION="pgsql"
        DB_DATABASE=firefly
        DB_USERNAME=firefly
        DB_PASSWORD={{ with secret "database/static-creds/firefly" }}{{ .Data.password }}{{ end }}

        APP_KEY={{ with secret "secret/firefly/app-key" }}{{ .Data.data.key }}{{ end }}
        EOH
        destination = "secrets/vars.env"
        env = true
      }

      resources {
        cpu = 300
        memory = 256
      }
    }

    task "csv-importer" {
      driver = "docker"

      service {
        name = "firefly-csv"
        port = "firefly-csv"
        address_mode = "host"

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.firefly-csv.rule=Host(`firefly-csv.service.consul`)",
          "traefik.http.routers.firefly-csv.tls=true"
        ]
      }

      env {
        FIREFLY_III_URL="https://firefly.service.consul"
        APP_URL="https://firefly-csv.service.consul"
        TRUSTED_PROXIES="**"
        VERIFY_TLS_SECURITY="false"
      }

      config {
        image = "fireflyiii/csv-importer:${var.versions.firefly-csv}"

        ports = [
          "firefly-csv"
        ]
      }

      resources {
        cpu = 300
        memory = 256
      }
    }
  }
}
