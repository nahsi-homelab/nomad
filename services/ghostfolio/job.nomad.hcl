job "ghostfolio" {
  datacenters = ["syria"]
  namespace   = "services"

  group "ghostfolio" {
    ephemeral_disk {
      size    = 300
      migrate = true
      sticky  = true
    }

    network {
      mode = "bridge"

      port "http" {}
    }

    service {
      name = "ghostfolio"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.ghostfolio.entrypoints=public",
        "traefik.http.routers.ghostfolio.rule=Host(`ghostfolio.nahsi.dev`)",
      ]

      check {
        name     = "ghostfolio HTTP"
        port     = "http"
        type     = "http"
        path     = "/api/v1/health"
        interval = "10s"
        timeout  = "1s"
      }
    }

    task "ghostfolio" {
      driver = "docker"

      vault {
        policies = ["ghostfolio"]
      }

      env {
        NODE_ENV        = "production"
        PORT            = NOMAD_PORT_http
        REDIS_HOST      = "127.0.0.1"
        REQUEST_TIMEOUT = 3000
      }

      config {
        image      = "ghostfolio/ghostfolio:2"
        force_pull = true
        ports = [
          "http",
        ]
      }

      template {
        data = <<-EOF
        {{- with secret "postgres/creds/ghostfolio" }}
        DATABASE_URL='postgresql://{{ .Data.username }}:{{ .Data.password }}@master.postgres.service.consul:5432/ghostfolio'
        {{- end }}
        {{- with secret "secret/ghostfolio" }}
        JWT_SECRET_KEY='{{ .Data.data.jwt_secret_key }}'
        ACCESS_TOKEN_SALT='{{ .Data.data.access_token_salt }}'
        {{- end }}
        EOF

        destination = "secrets/secrets.env"
        env         = true
      }

      resources {
        cpu        = 500
        memory     = 512
        memory_max = 1024
      }
    }

    task "redis" {
      driver = "docker"

      config {
        image = "redis:7"
        args = [
          "/local/redis.conf"
        ]
      }

      template {
        data        = <<-EOF
        maxmemory {{ env "NOMAD_MEMORY_LIMIT" | parseInt | subtract 16 }}mb
        dir /alloc/data
        stop-writes-on-bgsave-error no
        dbfilename dump.rdb
        EOF
        destination = "local/redis.conf"
      }

      resources {
        cpu        = 200
        memory     = 256
        memory_max = 512
      }
    }
  }
}
