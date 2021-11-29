variables {
  versions = {
    minio = "RELEASE.2021-11-24T23-19-33Z"
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
      port "http" {
        to = 9000
        static = 9000
      }

      port "console" {
        to = 9001
        static = 9001
      }
    }

    service {
      name = "minio-console"
      port = "console"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.minio.rule=Host(`minio.service.consul`)",
        "traefik.http.routers.minio.entrypoints=https",
        "traefik.http.routers.minio.tls=true",
      ]

      check {
        name     = "Minio liveness"
        type     = "http"
        protocol = "https"
        port     = "http"
        path     = "/minio/health/live"
        interval = "10s"
        timeout  = "2s"

        tls_skip_verify = true
      }
    }

    service {
      name = "minio"
      port = "http"

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
      port = "http"
    }

    volume "minio" {
      type = "host"
      source = "minio"
    }

    task "minio" {
      driver = "docker"
      user   = "nobody"

      vault {
        policies = ["minio"]
      }

      volume_mount {
        volume = "minio"
        destination = "/data"
      }

      env {
        MINIO_USERNAME = "nobody"
          
        MINIO_SERVER_URL = "https://minio-1.service.consul"
        MINIO_BROWSER_REDIRECT_URL = "https://minio.service.consul"
        MINIO_SITE_REGION = "${NOMAD_DC}"
        MINIO_PROMETHEUS_AUTH_TYPE = "public"
      }

      config {
        image = "minio/minio:${var.versions.minio}"
        hostname = "minio-${meta.minio_node_id}.service.consul"

        ports = [
          "http",
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
        {{- with secret "pki/issue/internal" "common_name=minio.service.consul" "alt_names=*.service.consul,localhost" -}}
        {{ .Data.issuing_ca }}{{ end }}
        EOH

        destination = "secrets/certs/CAs/public.crt"
        change_mode = "restart"
        splay       = "1m"
      }

      template {
        data =<<-EOH
        {{- with secret "pki/issue/internal" "common_name=minio.service.consul" "alt_names=*.service.consul,localhost" -}}
        {{ .Data.certificate }}{{ end }}
        EOH

        destination = "secrets/certs/public.crt"
        change_mode = "restart"
        splay       = "1m"
      }

      template {
        data =<<-EOH
        {{- with secret "pki/issue/internal" "common_name=minio.service.consul" "alt_names=*.service.consul,localhost" -}}
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
