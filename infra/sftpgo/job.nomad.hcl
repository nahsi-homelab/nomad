variables {
  versions = {
    sftpgo = "2.2.0-alpine"
    promtail = "2.4.1"
  }
}

job "sftpgo" {
  datacenters = [
    "syria",
    "asia"
  ]

  namespace = "infra"

  group "sftpgo" {
    ephemeral_disk {}

    network {
      port "http" {
        to = 8080
      }
      port "webdav" {
        to = 8088
      }
      port "promtail" {
        to = 3000
      }
    }

    service {
      name = "promtail"
      port = "promtail"

      meta {
        sidecar_to = "sftpgo"
      }

      check {
        type     = "http"
        path     = "/ready"
        interval = "10s"
        timeout  = "2s"
      }
    }

    service {
      name = "sftpgo"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.sftpgo-http.rule=Host(`sftpgo.service.consul`)",
        "traefik.http.routers.sftpgo-http.entrypoints=https",
        "traefik.http.routers.sftpgo-http.tls=true",
      ]

      check {
        name     = "sftpgo HTTP"
        type     = "http"
        path     = "/healthz"
        interval = "10s"
        timeout  = "2s"
      }
    }

    service {
      name = "sftpgo-webdav"
      port = "webdav"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.sftpgo-webdav.rule=Host(`sftpgo.service.consul`) && PathPrefix(`/dav`)",
        "traefik.http.middlewares.sftpgo-webdav-stripprefix.stripprefix.prefixes=/dav",
        "traefik.http.routers.sftpgo-webdav.middlewares=sftpgo-webdav-stripprefix@consulcatalog",
        "traefik.http.routers.sftpgo-webdav.entrypoints=https",
        "traefik.http.routers.sftpgo-webdav.tls=true",
      ]
    }

    task "sftpgo" {
      driver = "docker"
      user   = "nobody"

      vault {
        policies = ["sftpgo"]
      }

      env {
        SFTPGO_CONFIG_DIR="${NOMAD_ALLOC_DIR}/data"
        SFTPGO_CONFIG_FILE="/local/sftpgo.yml"
      }

      config {
        image = "drakkan/sftpgo:v${var.versions.sftpgo}"

        ports = [
          "http",
          "webdav"
        ]
      }

      template {
        data = file("sftpgo.yml")
        destination = "local/sftpgo.yml"
      }

      template {
        data = <<EOF
SFTPGO_DATA_PROVIDER__PASSWORD={{- with secret "database/static-creds/sftpgo" -}}{{ .Data.password }}{{ end -}}
EOF

        destination = "secrets/vars.env"
        change_mode = "noop"
        env = true
      }

      resources {
        cpu    = 100
        memory = 256
      }
    }

    task "promtail" {
      driver = "docker"
      user   = "nobody"

      lifecycle {
        hook    = "poststart"
        sidecar = true
      }

      resources {
        cpu = 50
        memory = 64
      }

      config {
        image = "grafana/promtail:${var.versions.promtail}"

        args = [
          "-config.file=local/promtail.yml"
        ]

        ports = [
          "promtail"
        ]
      }

      template {
        data = file("promtail.yml")
        destination = "local/promtail.yml"
      }
    }
  }
}
