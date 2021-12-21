variables {
  versions = {
    minio = "RELEASE.2021-12-10T23-03-39Z"
  }
}

job "minio" {
  datacenters = [
    "syria",
    "asia"
  ]

  namespace = "infra"

  constraint {
    distinct_property = meta.minio_node_id
  }

  update {
    max_parallel = 1
    stagger      = "1m"
  }

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
      name = "minio-console"
      port = "console"

      tags = [
        "ingress.enable=true",
        "ingress.http.routers.minio-ui.rule=Host(`minio.nahsi.dev`)",
        "ingress.http.routers.minio-ui.entrypoints=https",
        "ingress.http.routers.minio-ui.tls=true",
        "ingress.http.services.minio-ui.loadbalancer.server.scheme=https",
        "ingress.http.services.minio-ui.loadbalancer.serverstransport=skipverify@file",
      ]

      check {
        name     = "Minio liveness"
        type     = "http"
        protocol = "https"
        port     = "api"
        path     = "/minio/health/live"
        interval = "10s"
        timeout  = "2s"

        tls_skip_verify = true
      }
    }

    service {
      name = "minio"
      port = "api"

      tags = [
        "ingress.enable=true",
        "ingress.http.routers.minio-api.rule=Host(`s3.nahsi.dev`)",
        "ingress.http.routers.minio-api.entrypoints=https",
        "ingress.http.routers.minio-api.tls=true",
        "ingress.http.services.minio-api.loadbalancer.server.scheme=https",
        "ingress.http.services.minio-api.loadbalancer.serverstransport=skipverify@file",
      ]

      check {
        name     = "Minio liveness"
        type     = "http"
        protocol = "https"
        path     = "/minio/health/live"
        interval = "10s"
        timeout  = "2s"

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
        MINIO_SITE_REGION = "homelab"
          
        MINIO_SERVER_URL           = "https://s3.nahsi.dev"
        MINIO_BROWSER_REDIRECT_URL = "https://minio.nahsi.dev"
        MINIO_PROMETHEUS_URL       = "http://prometheus.service.consul:9090"
      }

      config {
        image    = "minio/minio:${var.versions.minio}"
        hostname = "minio-${meta.minio_node_id}.service.consul"

        ports = [
          "api",
          "console"
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
        data =<<-EOF
        MINIO_ROOT_USER={{ with secret "secret/minio/root" }}{{ .Data.data.username }}{{ end }}
        MINIO_ROOT_PASSWORD={{ with secret "secret/minio/root" }}{{ .Data.data.password }}{{ end }}
        EOF

        destination = "secrets/vars.env"
        change_mode = "noop"
        env         = true
      }

      template {
        data =<<-EOH
        {{- with secret "pki/issue/internal" "common_name=minio.service.consul" "alt_names=*.service.consul" -}}
        {{ .Data.issuing_ca }}{{ end }}
        EOH

        destination = "secrets/certs/CAs/public.crt"
        change_mode = "restart"
        splay       = "1m"
      }

      template {
        data =<<-EOH
        {{- with secret "pki/issue/internal" "common_name=minio.service.consul" "alt_names=minio.service.consul,*.service.consul,localhost" "ip_sans=127.0.0.1" -}}
        {{ .Data.certificate }}{{ end }}
        EOH

        destination = "secrets/certs/public.crt"
        change_mode = "restart"
        splay       = "1m"
      }

      template {
        data =<<-EOH
        {{- with secret "pki/issue/internal" "common_name=minio.service.consul" "alt_names=minio.service.consul,*.service.consul,localhost" "ip_sans=127.0.0.1" -}}
        {{ .Data.private_key }}{{ end }}
        EOH

        change_mode = "restart"
        destination = "secrets/certs/private.key"
        splay       = "1m"
      }

      resources {
        cpu    = 200
        memory = 512
      }
    }
  }
}
