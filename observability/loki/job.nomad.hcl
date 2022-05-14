variables {
  versions = {
    loki = "2.5.0"
  }
}

locals {
  certs = {
    "CA"   = "issuing_ca",
    "cert" = "certificate",
    "key"  = "private_key",
  }
}

job "loki" {
  datacenters = [
    "syria",
  ]
  namespace = "observability"

  vault {
    policies = ["loki"]
  }

  group "compactor" {
    count = 1

    ephemeral_disk {
      size    = 1000
      migrate = true
      sticky  = true
    }

    network {
      mode = "bridge"

      port "http" {}
      port "health" {}
      port "grpc" {}
    }

    service {
      name = "loki-compactor"
      port = "http"

      meta {
        alloc_id  = NOMAD_ALLOC_ID
        component = "compactor"
      }

      tags = [
        "traefik.enable=true",
        "traefik.consulcatalog.connect=true",
        "traefik.http.routers.loki-compactor-ring.entrypoints=https",
        "traefik.http.routers.loki-compactor-ring.rule=Host(`loki-compactor.service.consul`) && Path(`/compactor/ring`)",
      ]

      check {
        name     = "Loki compactor"
        port     = "health"
        type     = "http"
        path     = "/ready"
        interval = "20s"
        timeout  = "1s"
      }

      connect {
        sidecar_service {
          proxy {
            local_service_port = 80

            expose {
              path {
                path            = "/metrics"
                protocol        = "http"
                local_path_port = 80
                listener_port   = "http"
              }

              path {
                path            = "/ready"
                protocol        = "http"
                local_path_port = 80
                listener_port   = "health"
              }
            }
          }
        }
      }
    }

    task "compactor" {
      driver       = "docker"
      user         = "nobody"
      kill_timeout = "90s"

      config {
        image = "grafana/loki:${var.versions.loki}"
        ports = [
          "http",
          "health",
          "grpc",
        ]

        args = [
          "-config.file=/local/loki.yml",
          "-config.expand-env=true",
          "-target=compactor",
        ]
      }

      template {
        data        = file("loki.yml")
        destination = "local/loki.yml"
      }

      template {
        data = <<-EOH
        {{ with secret "secret/minio/loki" }}
        S3_ACCESS_KEY_ID={{ .Data.data.access_key }}
        S3_SECRET_ACCESS_KEY={{ .Data.data.secret_key }}
        {{- end }}
        EOH

        destination = "secrets/s3.env"
        splay       = "1m"
        env         = true
      }

      dynamic "template" {
        for_each = local.certs
        content {
          data = <<-EOH
          {{- with secret "pki/issue/internal" "ttl=10d" "common_name=loki-compactor.service.consul" (env "attr.unique.network.ip-address" | printf "ip_sans=%s") -}}
          {{ .Data.${template.value} }}
          {{- end -}}
          EOH

          destination = "secrets/certs/${template.key}.pem"
          change_mode = "restart"
          splay       = "1m"
        }
      }

      resources {
        cpu        = 3000
        memory     = 256
        memory_max = 1024
      }
    }
  }

  group "distibutor" {
    count = 2

    network {
      mode = "bridge"

      port "http" {}
      port "health" {}
      port "grpc" {}
    }

    service {
      name = "loki-distributor"
      port = "http"

      meta {
        alloc_id  = NOMAD_ALLOC_ID
        component = "distributor"
      }

      tags = [
        "traefik.enable=true",
        "traefik.consulcatalog.connect=true",

        "traefik.http.routers.loki-distributor.entrypoints=https",
        "traefik.http.routers.loki-distributor.rule=Host(`loki-distributor.service.consul`)",
        "traefik.http.middlewares.loki-distributor.basicauth.users=promtail:$$apr1$$wnir40yf$$vcxJYiqcEQLknQAZcpy/I1",
        "traefik.http.routers.loki-distirbutor.middlewares=loki-distributor@consulcatalog",

        "traefik.http.routers.loki-distributor-ring.entrypoints=https",
        "traefik.http.routers.loki-distributor-ring.rule=Host(`loki-distributor.cinarra.com`) && Path(`/distributor/ring`)",
      ]

      check {
        name     = "Loki distibutor"
        port     = "health"
        type     = "http"
        path     = "/ready"
        interval = "20s"
        timeout  = "1s"
      }

      connect {
        sidecar_service {
          proxy {
            local_service_port = 80

            expose {
              path {
                path            = "/metrics"
                protocol        = "http"
                local_path_port = 80
                listener_port   = "http"
              }

              path {
                path            = "/ready"
                protocol        = "http"
                local_path_port = 80
                listener_port   = "health"
              }
            }
          }
        }
      }
    }

    task "distibutor" {
      driver       = "docker"
      user         = "nobody"
      kill_timeout = "90s"

      config {
        image = "grafana/loki:${var.versions.loki}"
        ports = [
          "http",
          "health",
          "grpc",
        ]

        args = [
          "-config.file=/local/loki.yml",
          "-config.expand-env=true",
          "-target=distributor",
        ]
      }

      template {
        data        = file("loki.yml")
        destination = "local/loki.yml"
      }

      dynamic "template" {
        for_each = local.certs
        content {
          data = <<-EOH
          {{- with secret "pki/issue/internal" "ttl=10d" "common_name=loki-distributer.service.consul" (env "attr.unique.network.ip-address" | printf "ip_sans=%s") -}}
          {{ .Data.${template.value} }}
          {{- end -}}
          EOH

          destination = "secrets/certs/${template.key}.pem"
          change_mode = "restart"
          splay       = "5m"
        }
      }

      resources {
        cpu        = 200
        memory     = 128
        memory_max = 1024
      }
    }
  }

  group "ingester" {
    count = 2

    constraint {
      distinct_property = node.unique.name
    }

    ephemeral_disk {
      size    = 4000
      migrate = true
      sticky  = true
    }

    network {
      mode = "bridge"

      port "http" {}
      port "health" {}
      port "grpc" {}
    }

    service {
      name = "loki-ingester"
      port = "http"

      meta {
        alloc_id  = NOMAD_ALLOC_ID
        component = "ingester"
      }

      tags = [
        "traefik.enable=true",
        "traefik.consulcatalog.connect=true",
        "traefik.http.routers.loki-ingester-ring.entrypoints=https",
        "traefik.http.routers.loki-ingester-ring.rule=Host(`loki-ingester.service.consul`) && Path(`/ring`)",
      ]

      check {
        name     = "Loki ingester"
        port     = "health"
        type     = "http"
        path     = "/ready"
        interval = "20s"
        timeout  = "1s"
      }

      connect {
        sidecar_service {
          proxy {
            local_service_port = 80

            expose {
              path {
                path            = "/metrics"
                protocol        = "http"
                local_path_port = 80
                listener_port   = "http"
              }

              path {
                path            = "/ready"
                protocol        = "http"
                local_path_port = 80
                listener_port   = "health"
              }
            }
          }
        }
      }
    }

    task "ingester" {
      driver       = "docker"
      user         = "nobody"
      kill_timeout = "90s"

      config {
        image = "grafana/loki:${var.versions.loki}"
        ports = [
          "http",
          "health",
          "grpc",
        ]

        args = [
          "-config.file=/local/loki.yml",
          "-config.expand-env=true",
          "-target=ingester",
        ]
      }

      template {
        data        = file("loki.yml")
        destination = "local/loki.yml"
      }

      template {
        data = <<-EOH
        {{ with secret "secret/minio/loki" }}
        S3_ACCESS_KEY_ID={{ .Data.data.access_key }}
        S3_SECRET_ACCESS_KEY={{ .Data.data.secret_key }}
        {{- end }}
        EOH

        destination = "secrets/s3.env"
        splay       = "5m"
        env         = true
      }

      dynamic "template" {
        for_each = local.certs
        content {
          data = <<-EOH
          {{- with secret "pki/issue/internal" "ttl=10d" "common_name=loki-ingestor.service.consul" (env "attr.unique.network.ip-address" | printf "ip_sans=%s") -}}
          {{ .Data.${template.value} }}
          {{- end -}}
          EOH

          destination = "secrets/certs/${template.key}.pem"
          change_mode = "restart"
          splay       = "1m"
        }
      }

      resources {
        cpu        = 300
        memory     = 128
        memory_max = 2048
      }
    }
  }

  group "querier" {
    count = 2

    network {
      mode = "bridge"

      port "http" {}
      port "health" {}
      port "grpc" {}
    }

    service {
      name = "loki-querier"
      port = "http"

      meta {
        alloc_id  = NOMAD_ALLOC_ID
        component = "querier"
      }

      check {
        name     = "Loki querier"
        port     = "health"
        type     = "http"
        path     = "/ready"
        interval = "50s"
        timeout  = "1s"
      }

      connect {
        sidecar_service {
          proxy {
            local_service_port = 80

            expose {
              path {
                path            = "/metrics"
                protocol        = "http"
                local_path_port = 80
                listener_port   = "http"
              }

              path {
                path            = "/ready"
                protocol        = "http"
                local_path_port = 80
                listener_port   = "health"
              }
            }
          }
        }
      }
    }

    task "querier" {
      driver       = "docker"
      user         = "nobody"
      kill_timeout = "90s"

      config {
        image = "grafana/loki:${var.versions.loki}"
        ports = [
          "http",
          "health",
          "grpc",
        ]

        args = [
          "-config.file=/local/loki.yml",
          "-config.expand-env=true",
          "-target=querier",
        ]
      }

      template {
        data        = file("loki.yml")
        destination = "local/loki.yml"
      }

      template {
        data = <<-EOH
        {{ with secret "secret/minio/loki" }}
        S3_ACCESS_KEY_ID={{ .Data.data.access_key }}
        S3_SECRET_ACCESS_KEY={{ .Data.data.secret_key }}
        {{- end }}
        EOH

        destination = "secrets/s3.env"
        splay       = "5m"
        env         = true
      }

      dynamic "template" {
        for_each = local.certs
        content {
          data = <<-EOH
          {{- with secret "pki/issue/internal" "ttl=10d" "common_name=loki-querier.service.consul" (env "attr.unique.network.ip-address" | printf  "ip_sans=%s") -}}
          {{ .Data.${template.value} }}
          {{- end -}}
          EOH

          destination = "secrets/certs/${template.key}.pem"
          change_mode = "restart"
          splay       = "1m"
        }
      }

      resources {
        cpu        = 200
        memory     = 128
        memory_max = 2048
      }
    }
  }

  group "query-scheduler" {
    count = 2

    network {
      mode = "bridge"

      port "http" {}
      port "health" {}
      port "grpc" {
        to     = 9096
        static = 9096
      }
    }

    service {
      name = "loki-query-scheduler"
      port = "http"

      meta {
        alloc_id  = NOMAD_ALLOC_ID
        component = "query-scheduler"
      }

      check {
        name     = "Loki query-scheduler"
        port     = "health"
        type     = "http"
        path     = "/ready"
        interval = "20s"
        timeout  = "1s"
      }

      connect {
        sidecar_service {
          proxy {
            local_service_port = 80

            expose {
              path {
                path            = "/metrics"
                protocol        = "http"
                local_path_port = 80
                listener_port   = "http"
              }

              path {
                path            = "/ready"
                protocol        = "http"
                local_path_port = 80
                listener_port   = "health"
              }
            }
          }
        }
      }
    }

    task "query-scheduler" {
      driver       = "docker"
      user         = "nobody"
      kill_timeout = "90s"

      config {
        image = "grafana/loki:${var.versions.loki}"
        ports = [
          "http",
          "health",
          "grpc",
        ]

        args = [
          "-config.file=/local/loki.yml",
          "-config.expand-env=true",
          "-target=query-scheduler",
        ]
      }

      template {
        data        = file("loki.yml")
        destination = "local/loki.yml"
      }

      dynamic "template" {
        for_each = local.certs
        content {
          data = <<-EOH
          {{- with secret "pki/issue/internal" "ttl=10d" "common_name=loki-query-scheduler.service.consul" (env "attr.unique.network.ip-address" | printf  "ip_sans=%s") -}}
          {{ .Data.${template.value} }}
          {{- end -}}
          EOH

          destination = "secrets/certs/${template.key}.pem"
          change_mode = "restart"
          splay       = "1m"
        }
      }

      resources {
        cpu        = 100
        memory     = 64
        memory_max = 128
      }
    }
  }

  group "query-frontend" {
    count = 2

    network {
      mode = "bridge"

      port "http" {}
      port "health" {}
      port "grpc" {}
    }

    service {
      name = "loki-query-frontend"
      port = "http"

      meta {
        alloc_id  = NOMAD_ALLOC_ID
        component = "query-frontend"
      }

      tags = [
        "traefik.enable=true",
        "traefik.consulcatalog.connect=true",

        "traefik.http.routers.loki-query-frontend.entrypoints=https",
        "traefik.http.routers.loki-query-frontend.rule=Host(`loki-query-frontend.service.consul`)",
        "traefik.http.middlewares.loki-query-frontend.basicauth.users=grafana:$apr1$5yBhGAwc$SrXPFIfimv5cCNH8UrDpE/",
        "traefik.http.routers.loki-query-frontend.middlewares=loki-query-frontend@consulcatalog",
      ]

      check {
        name     = "Loki query-frontend"
        port     = "health"
        type     = "http"
        path     = "/ready"
        interval = "20s"
        timeout  = "1s"
      }

      connect {
        sidecar_service {
          proxy {
            local_service_port = 80

            expose {
              path {
                path            = "/metrics"
                protocol        = "http"
                local_path_port = 80
                listener_port   = "http"
              }

              path {
                path            = "/ready"
                protocol        = "http"
                local_path_port = 80
                listener_port   = "health"
              }
            }
          }
        }
      }
    }

    task "query-frontend" {
      driver       = "docker"
      user         = "nobody"
      kill_timeout = "90s"

      config {
        image = "grafana/loki:${var.versions.loki}"
        ports = [
          "http",
          "health",
          "grpc",
        ]

        args = [
          "-config.file=/local/loki.yml",
          "-config.expand-env=true",
          "-target=query-frontend",
        ]
      }

      template {
        data        = file("loki.yml")
        destination = "local/loki.yml"
      }

      dynamic "template" {
        for_each = local.certs
        content {
          data = <<-EOH
          {{- with secret "pki/issue/internal" "ttl=10d" "common_name=loki-query-frontend.service.consul" (env "attr.unique.network.ip-address" | printf  "ip_sans=%s") -}}
          {{ .Data.${template.value} }}
          {{- end -}}
          EOH

          destination = "secrets/certs/${template.key}.pem"
          change_mode = "restart"
          splay       = "1m"
        }
      }

      resources {
        cpu        = 100
        memory     = 64
        memory_max = 128
      }
    }
  }

  group "index-gateway" {
    count = 1

    ephemeral_disk {
      size    = 1000
      migrate = true
      sticky  = true
    }

    network {
      mode = "bridge"

      port "http" {}
      port "health" {}
      port "grpc" {
        to     = 9097
        static = 9097
      }
    }

    service {
      name = "loki-index-gateway"
      port = "http"

      meta {
        alloc_id  = NOMAD_ALLOC_ID
        component = "index-gateway"
      }

      check {
        name     = "Loki index-gateway"
        port     = "health"
        type     = "http"
        path     = "/ready"
        interval = "10s"
        timeout  = "1s"
      }

      connect {
        sidecar_service {
          proxy {
            local_service_port = 80

            expose {
              path {
                path            = "/metrics"
                protocol        = "http"
                local_path_port = 80
                listener_port   = "http"
              }

              path {
                path            = "/ready"
                protocol        = "http"
                local_path_port = 80
                listener_port   = "health"
              }
            }
          }
        }
      }
    }

    task "index-gateway" {
      driver       = "docker"
      user         = "nobody"
      kill_timeout = "90s"

      config {
        image = "grafana/loki:${var.versions.loki}"
        ports = [
          "http",
          "health",
          "grpc",
        ]

        args = [
          "-config.file=/local/loki.yml",
          "-config.expand-env=true",
          "-target=index-gateway",
        ]
      }

      template {
        data        = file("loki.yml")
        destination = "local/loki.yml"
      }

      template {
        data = <<-EOH
        {{ with secret "secret/minio/loki" }}
        S3_ACCESS_KEY_ID={{ .Data.data.access_key }}
        S3_SECRET_ACCESS_KEY={{ .Data.data.secret_key }}
        {{- end }}
        EOH

        destination = "secrets/s3.env"
        splay       = "1m"
        env         = true
      }

      dynamic "template" {
        for_each = local.certs
        content {
          data = <<-EOH
          {{- with secret "pki/issue/internal" "ttl=10d" "common_name=loki-index-gateway.service.consul" (env "attr.unique.network.ip-address" | printf "ip_sans=%s") -}}
          {{ .Data.${template.value} }}
          {{- end -}}
          EOH

          destination = "secrets/certs/${template.key}.pem"
          change_mode = "restart"
          splay       = "1m"
        }
      }

      resources {
        cpu        = 200
        memory     = 128
        memory_max = 1024
      }
    }
  }
}
