job "wish" {
  datacenters = ["syria"]
  namespace   = "services"

  group "wish" {
    network {
      port "http" {
        to = 80
      }
    }

    service {
      name = "wish"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.wish.entrypoints=public",
        "traefik.http.routers.wish.rule=Host(`wish.nahsi.dev`)"
      ]
    }

    task "wish" {
      driver = "docker"

      vault {
        policies = ["wish"]
      }

      config {
        image = "hiob/wishthis:release-candidate"
        ports = [
          "http",
        ]
        volumes = [
          "local/config.php:/var/www/html/src/config/config.php",
        ]
      }

      template {
        data = <<-EOF
        {{- with secret "mariadb/static-creds/wish" }}
        DATABASE_HOST=mariadb.service.consul:3106
        DATABASE_NAME=wish
        DATABASE_USER={{ .Data.username }}
        DATABASE_PASSWORD={{ .Data.password }}
        {{- end }}
        EOF

        destination = "secrets/db.env"
        env         = true
      }

      template {
        data          = <<-EOH
        {{ key "configs/services/wish/config.php" }}
        EOH
        destination   = "local/config.php"
      }

      resources {
        cpu        = 500
        memory     = 256
        memory_max = 512
      }
    }
  }
}
