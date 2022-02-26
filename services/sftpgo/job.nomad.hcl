variables {
  versions = {
    sftpgo = "2.2.2-alpine"
  }
}

job "sftpgo" {
  datacenters = [
    "syria",
    "asia"
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

      check {
        name     = "sftpgo HTTP"
        port     = "http"
        type     = "http"
        path     = "/healthz"
        interval = "10s"
        timeout  = "2s"
      }
    }

    service {
      name = "sftpgo"
      port = "http"

      tags = [
        "ingress.enable=true",
        "ingress.http.routers.sftpgo-http.entrypoints=https",
        "ingress.http.routers.sftpgo-http.rule=Host(`files.nahsi.dev`) && PathPrefix(`/sftpgo`)",
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
        "ingress.enable=true",
        "ingress.http.routers.sftpgo-webdav.entrypoints=https",
        "ingress.http.routers.sftpgo-webdav.rule=Host(`files.nahsi.dev`) && PathPrefix(`/dav`)",
        "ingress.http.middlewares.sftpgo-webdav-stripprefix.stripprefix.prefixes=/dav",
        "ingress.http.routers.sftpgo-webdav.middlewares=sftpgo-webdav-stripprefix@consulcatalog",
      ]

      check {
        name     = "sftpgo HTTP"
        type     = "http"
        port     = "http"
        path     = "/healthz"
        interval = "10s"
        timeout  = "2s"
      }
    }

    service {
      name = "sftpgo-sftp"
      port = "sftp"

      tags = [
        "ingress.enable=true",
        "ingress.tcp.services.sftpgo-sftp.loadBalancer.proxyProtocol.version=2",
        "ingress.tcp.routers.sftpgo-sftp.entrypoints=sftp",
        "ingress.tcp.routers.sftpgo-sftp.rule=HostSNI(`*`)",
      ]

      check {
        name     = "sftpgo HTTP"
        port     = "http"
        type     = "http"
        path     = "/healthz"
        interval = "10s"
        timeout  = "2s"
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
        splay       = "1m"
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
