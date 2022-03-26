variables {
  versions = {
    loki  = "2.4.2"
    redis = "6.2"
    resec = "latest"
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
    "asia",
    "pontus",
  ]
  namespace = "observability"

  spread {
    attribute = node.datacenter
  }

  spread {
    attribute = node.unique.name
  }

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

      check {
        name     = "Loki compactor"
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
        cpu    = 500
        memory = 256
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
      name = "loki-distibutor"
      port = "http"

      check {
        name     = "Loki distibutor"
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
          splay       = "1m"
        }
      }

      resources {
        cpu    = 500
        memory = 256
      }
    }
  }

  group "ingester" {
    count = 3

    ephemeral_disk {
      size    = 4100
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

      check {
        name     = "Loki ingester"
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
        splay       = "1m"
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
        cpu    = 500
        memory = 256
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

      check {
        name     = "Loki querier"
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

      dynamic "template" {
        for_each = local.certs
        content {
          data = <<-EOH
          {{- with secret "pki/issue/internal" "ttl=10d" "common_name=loki-querier.service.consul" (env "attr.unique.network.ip-address" | printf  "ip_sans=%s,127.0.0.1") -}}
          {{ .Data.${template.value} }}
          {{- end -}}
          EOH

          destination = "secrets/certs/${template.key}.pem"
          change_mode = "restart"
          splay       = "1m"
        }
      }

      resources {
        cpu    = 500
        memory = 256
      }
    }
  }

  group "query-scheduler" {
    count = 2

    network {
      mode = "bridge"

      port "http" {}
      port "health" {}
      port "grpc" {}
    }

    service {
      name = "loki-query-scheduler"
      port = "http"

      check {
        name     = "Loki query-scheduler"
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
        cpu    = 500
        memory = 256
      }
    }
  }

  group "query-frontend" {
    count = 2

    network {
      mode = "bridge"

      dns {
        servers = [
          "192.168.130.1",
          "192.168.230.1",
        ]
      }

      port "http" {}
      port "health" {}
      port "grpc" {}
    }

    service {
      name = "loki-query-frontend"
      port = "http"

      check {
        name     = "Loki query-frontend"
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

            upstreams {
              destination_name = "loki-querier"
              local_bind_port  = 3100
            }

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
        cpu    = 500
        memory = 256
      }
    }
  }

  group "index-gateway" {
    count = 2

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
        to     = 3101
        static = 3101
      }
    }

    service {
      name = "loki-index-gateway"
      port = "http"

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
          "-server.grpc-listen-port=${NOMAD_PORT_grpc}",
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
          {{- with secret "pki/issue/internal" "ttl=10d" "common_name=loki-index-gateway.service.consul" (env "attr.unique.network.ip-address" | printf  "ip_sans=%s") -}}
          {{ .Data.${template.value} }}
          {{- end -}}
          EOH

          destination = "secrets/certs/${template.key}.pem"
          change_mode = "restart"
          splay       = "1m"
        }
      }

      resources {
        cpu    = 500
        memory = 256
      }
    }
  }
}
