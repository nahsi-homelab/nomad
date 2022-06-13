variables {
  versions = {
    snipeit = "6.0.2-alpine"
  }
}

job "snipeit" {
  datacenters = ["syria"]
  namespace   = "services"

  group "snipeit" {
    network {
      port "http" {
        to = 80
      }
    }

    service {
      name = "snipeit"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.snipeit.entrypoints=public",
        "traefik.http.routers.snipeit.rule=Host(`snipeit.nahsi.dev`)",
      ]

      check {
        name     = "Snipe-IT HTTP"
        port     = "http"
        type     = "http"
        path     = "/health"
        interval = "10s"
        timeout  = "1s"
      }
    }

    volume "snipeit" {
      type   = "host"
      source = "snipeit"
    }

    task "snipeit" {
      driver = "docker"

      vault {
        policies = ["snipeit"]
      }

      env {
        APP_ENV             = "production"
        APP_DEBUG           = false
        APP_URL             = "https://snipeit.nahsi.dev"
        APP_FORCE_TLS       = true
        APP_TIMEZONE        = "Europe/Moscow"
        APP_LOCALE          = "en"
        APP_TRUSTED_PROXIES = "*"
        MAX_RESULTS         = 500

        SESSION_LIFETIME = 30
        EXPIRE_ON_CLOSE  = false
        ENCRYPT          = true
        COOKIE_NAME      = "snipeit_session"
        COOKIE_DOMAIN    = "snipeit.nahsi.dev"
        SECURE_COOKIES   = true
        ENABLE_HSTS      = true

        BACKUP_ENV = false
      }

      volume_mount {
        volume      = "snipeit"
        destination = "/var/lib/snipeit"
      }

      config {
        image = "snipe/snipe-it:v${var.versions.snipeit}"
        ports = ["http"]
      }

      template {
        data = <<-EOF
        {{- with secret "secret/snipeit/secret" }}
        APP_KEY={{ .Data.data.key }}
        {{- end }}
        EOF

        destination = "secrets/secret.env"
        env         = true
      }

      template {
        data = <<-EOF
        {{- with secret "mariadb/static-creds/snipeit" }}
        DB_CONNECTION=mysql
        DB_HOST=mariadb.service.consul
        DB_PORT=3106
        DB_DATABASE=snipeit
        DB_USERNAME={{ .Data.username }}
        DB_PASSWORD={{ .Data.password }}
        DB_PREFIX=null
        DB_DUMP_PATH='/usr/bin'
        DB_CHARSET=utf8mb4
        DB_COLLATION=utf8mb4_unicode_ci
        {{- end }}
        EOF

        destination = "secrets/db.env"
        env         = true
      }

      /* template { */
      /*   data = <<-EOF */
      /*   {{- with secret "secret/keydb/users/default" }} */
      /*   REDIS_HOST=keydb.service.consul */
      /*   REDIS_PASSWORD={{ .Data.data.password }} */
      /*   REDIS_PORT=6379 */
      /*   {{- end }} */
      /*   EOF */

      /*   destination = "secrets/cache.env" */
      /*   env         = true */
      /* } */

      template {
        data = <<-EOF
        {{- with secret "secret/snipeit/smtp" }}
        MAIL_DRIVER=smtp
        MAIL_HOST=mail.nahsi.dev
        MAIL_PORT=465
        MAIL_USERNAME={{ .Data.data.username }}
        MAIL_PASSWORD={{ .Data.data.password }}
        MAIL_ENCRYPTION=ssl
        MAIL_FROM_ADDR=snipeit@nahsi.dev
        MAIL_FROM_NAME=Snipe-IT
        MAIL_REPLYTO_ADDR=snipeit@nahsi.dev
        MAIL_REPLYTO_NAME=Snipe-IT
        {{- end }}
        EOF

        destination = "secrets/mail.env"
        env         = true
      }

      resources {
        cpu        = 500
        memory     = 256
        memory_max = 512
      }
    }
  }
}
