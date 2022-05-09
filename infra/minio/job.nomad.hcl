variables {
  versions = {
    minio = "RELEASE.2022-05-08T23-50-31Z"
  }
}

locals {
  certs = {
    "public.crt"  = "certificate",
    "private.key" = "private_key",
  }
}

job "minio" {
  datacenters = [
    "syria",
    "asia"
  ]
  namespace = "infra"

  group "minio" {
    count = 4

    network {
      port "api" {
        to     = 9000
        static = 9000
      }

      port "console" {
        to     = 9001
        static = 9001
      }
    }

    service {
      name = "minio"
      port = "console"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.minio-ui.entrypoints=public",
        "traefik.http.routers.minio-ui.rule=Host(`minio.nahsi.dev`)",
        "traefik.http.services.minio-ui.loadbalancer.server.scheme=https",
        "traefik.http.services.minio-ui.loadbalancer.serverstransport=skipverify@file",
      ]

      check {
        name     = "Minio liveness"
        type     = "http"
        protocol = "https"
        port     = "api"
        path     = "/minio/health/live"
        interval = "20s"
        timeout  = "1s"

        tls_skip_verify = true
      }
    }

    service {
      name = "s3"
      port = "api"

      tags = [
        "traefik.enable=true",

        "traefik.http.routers.minio-api-pub.rule=Host(`s3.nahsi.dev`)",
        "traefik.http.routers.minio-api-pub.entrypoints=public",
        "traefik.http.services.minio-api-pub.loadbalancer.server.scheme=https",
        "traefik.http.services.minio-api-pub.loadbalancer.serverstransport=skipverify@file",

        "traefik.http.routers.minio-api.rule=Host(`s3.service.consul`)",
        "traefik.http.routers.minio-api.entrypoints=https",
        "traefik.http.services.minio-api.loadbalancer.server.scheme=https",
        "traefik.http.services.minio-api.loadbalancer.serverstransport=skipverify@file",
      ]

      check {
        name     = "Minio liveness"
        type     = "http"
        protocol = "https"
        path     = "/minio/health/live"
        interval = "20s"
        timeout  = "1s"

        tls_skip_verify = true
      }
    }

    service {
      name = "minio-${meta.minio_node_id}"
      port = "api"
    }

    volume "minio" {
      type   = "host"
      source = "minio"
    }

    task "minio" {
      driver = "docker"
      user   = "nobody"

      resources {
        cpu        = 300
        memory     = 512
        memory_max = 2048
      }

      vault {
        policies = ["minio"]
      }

      volume_mount {
        volume      = "minio"
        destination = "/data"
      }

      env {
        MINIO_USERNAME = "nobody"

        MINIO_SITE_NAME   = "homelab"
        MINIO_SITE_REGION = "syria"

        MINIO_SERVER_URL           = "https://s3.service.consul:9000"
        MINIO_BROWSER_REDIRECT_URL = "https://minio.nahsi.dev"
        MINIO_PROMETHEUS_URL       = "https://victoria-metrics.service.consul"
      }

      config {
        image    = "quay.io/minio/minio:${var.versions.minio}"
        hostname = "minio-${meta.minio_node_id}.service.consul"

        ports = [
          "api",
          "console",
        ]

        command = "minio"
        args = [
          "server",
          "--console-address=:9001",
          "--certs-dir=/secrets/certs",
          "https://minio-{1...4}.service.consul:9000/data",
        ]
      }

      template {
        data = <<-EOF
        MINIO_ROOT_USER={{ with secret "secret/minio/root" }}{{ .Data.data.username }}{{ end }}
        MINIO_ROOT_PASSWORD={{ with secret "secret/minio/root" }}{{ .Data.data.password }}{{ end }}
        EOF

        destination = "secrets/secrets.env"
        env         = true
      }

      template {
        data = <<-EOH
        {{- with secret "pki/issue/internal" "common_name=*.service.consul" -}}
        {{ .Data.issuing_ca }}{{ end }}
        EOH

        destination = "secrets/certs/CAs/public.crt"
        change_mode = "restart"
        splay       = "5m"
      }

      dynamic "template" {
        for_each = local.certs
        content {
          data = <<-EOH
          {{- with secret "pki/issue/internal" "ttl=31d" "common_name=s3.service.consul" (env "attr.unique.network.ip-address" | printf "ip_sans=%s,127.0.0.1") (env "meta.minio_node_id" | printf "alt_names=minio-%s.service.consul,minio.service.consul,localhost") -}}
          {{ .Data.${template.value} }}
          {{- end -}}
          EOH

          destination = "secrets/certs/${template.key}"
          change_mode = "restart"
          splay       = "5m"
        }
      }
    }
  }
}
