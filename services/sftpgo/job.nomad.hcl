variables {
  versions = {
    sftpgo = "2.3.1-alpine"
  }
}

job "sftpgo" {
  datacenters = [
    "syria",
  ]
  namespace = "services"

  group "sftpgo" {
    count = 2

    ephemeral_disk {
      size    = 1000
      migrate = true
      sticky  = true
    }

    network {
      port "http" {}
      port "metrics" {}
      port "webdav" {}
      port "ftp" {
        static = 20
      }
      port "sftp" {}
    }

    service {
      name = "sftpgo-metrics"
      port = "metrics"

      meta {
        alloc_id  = NOMAD_ALLOC_ID
      }

      check {
        name     = "SFTPGo HTTP"
        port     = "http"
        type     = "http"
        path     = "/healthz"
        interval = "20s"
        timeout  = "1s"
      }
    }

    service {
      name = "sftpgo"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.sftpgo-http.entrypoints=public",
        "traefik.http.routers.sftpgo-http.rule=Host(`files.nahsi.dev`) && PathPrefix(`/sftpgo`)",
      ]

      check {
        name     = "SFTPGo HTTP"
        type     = "http"
        path     = "/healthz"
        interval = "20s"
        timeout  = "1s"
      }
    }

    service {
      name = "sftpgo-webdav"
      port = "webdav"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.sftpgo-webdav.entrypoints=public",
        "traefik.http.routers.sftpgo-webdav.rule=Host(`files.nahsi.dev`) && PathPrefix(`/dav`)",
        "traefik.http.middlewares.sftpgo-webdav-stripprefix.stripprefix.prefixes=/dav",
        "traefik.http.routers.sftpgo-webdav.middlewares=sftpgo-webdav-stripprefix@consulcatalog",
      ]

      check {
        name     = "sftpgo HTTP"
        type     = "http"
        port     = "http"
        path     = "/healthz"
        interval = "20s"
        timeout  = "1s"
      }
    }

    service {
      name = "sftpgo-sftp"
      port = "sftp"

      tags = [
        "traefik.enable=true",
        "traefik.tcp.services.sftpgo-sftp.loadBalancer.proxyProtocol.version=2",
        "traefik.tcp.routers.sftpgo-sftp.entrypoints=sftp",
        "traefik.tcp.routers.sftpgo-sftp.rule=HostSNI(`*`)",
      ]

      check {
        name     = "SFTPGo HTTP"
        port     = "http"
        type     = "http"
        path     = "/healthz"
        interval = "20s"
        timeout  = "1s"
      }
    }

    task "sftpgo" {
      driver = "docker"
      user   = "nobody"

      vault {
        policies = ["sftpgo"]
      }

      resources {
        cpu    = 100
        memory = 256
      }

      env {
        SFTPGO_CONFIG_DIR  = "${NOMAD_ALLOC_DIR}/data"
        SFTPGO_CONFIG_FILE = "/local/sftpgo.yml"
      }

      config {
        image = "drakkan/sftpgo:v${var.versions.sftpgo}"

        ports = [
          "http",
          "webdav",
          "ftp",
          "sftp",
          "metrics",
        ]
      }

      template {
        data        = file("sftpgo.yml")
        destination = "local/sftpgo.yml"
      }

      template {
        data = <<-EOH
        {{ with secret "postgres/creds/sftpgo" }}
        SFTPGO_DATA_PROVIDER__USERNAME='{{ .Data.username }}'
        SFTPGO_DATA_PROVIDER__PASSWORD='{{ .Data.password }}'
        {{- end }}
        {{ with secret "secret/sftpgo/passphrase" }}
        SFTPGO_HTTPD__SIGNING_PASSPHRASE='{{ .Data.data.passphrase }}'
        {{- end }}
        EOH

        destination = "secrets/db.env"
        splay       = "3m"
        env         = true
      }

      dynamic "template" {
        for_each = ["id_rsa", "id_ecdsa", "id_ed25519"]
        content {
          destination = "secrets/ssh/${template.value}"
          data        = <<-EOH
          {{- with secret "secret/sftpgo/ssh" -}}
          {{ .Data.data.${template.value} }}
          {{- end -}}
          EOH
        }
      }
    }
  }
}
