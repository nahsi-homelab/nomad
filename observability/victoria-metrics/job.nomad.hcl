variables {
  versions = {
    vm = "1.73.0"
  }
}

job "victoria-metrics" {
  datacenters = [
    "syria",
    "asia"
  ]
  namespace = "observability"

  group "victoria-metrics" {
    network {
      mode = "bridge"
      port "http" {}
      port "health" {}
    }

    service {
      name = "victoria-metrics"
      port = "http"

      meta {
        alloc_id = NOMAD_ALLOC_ID
      }

      tags = [
        "traefik.enable=true",
        "traefik.consulcatalog.connect=true",
        "traefik.http.routers.vm.entrypoints=https",
        "traefik.http.routers.vm.rule=Host(`victoria-metrics.service.consul`)",
      ]

      connect {
        sidecar_service {
          proxy {
            local_service_port = 8428
            expose {
              path {
                path            = "/metrics"
                protocol        = "http"
                local_path_port = 8428
                listener_port   = "http"
              }
              path {
                path            = "/-/ready"
                protocol        = "http"
                local_path_port = 8428
                listener_port   = "health"
              }
            }
          }
        }
      }

      check {
        name     = "VictoriaMetrics HTTP"
        type     = "http"
        port     = "health"
        path     = "/-/ready"
        interval = "10s"
        timeout  = "2s"
      }
    }

    volume "victoria-metrics" {
      type   = "host"
      source = "victoria-metrics"
    }

    task "victoria-metrics" {
      driver       = "docker"
      user         = "nobody"
      kill_timeout = "10s"

      vault {
        policies = ["victoria-metrics"]
      }

      resources {
        cpu        = 100
        memory     = 128
        memory_max = 258
      }

      volume_mount {
        volume      = "victoria-metrics"
        destination = "/data"
      }

      config {
        image = "victoriametrics/victoria-metrics:v${var.versions.vm}"

        args = [
          "-httpListenAddr=127.0.0.1:8428",
          "-storageDataPath=/data",
          "-dedup.minScrapeInterval=10s",
        ]
      }
    }
  }

  group "vmagent" {
    count = 2
    update {
      min_healthy_time = "30s"
    }

    constraint {
      distinct_property = node.datacenter
    }

    ephemeral_disk {
      size   = 1100
      sticky = true
    }

    network {
      mode = "bridge"
      port "http" {}
      port "health" {}
    }

    service {
      name = "vmagent"
      port = "http"

      meta {
        alloc_id = NOMAD_ALLOC_ID
      }

      tags = [
        "traefik.enable=true",
        "traefik.consulcatalog.connect=true",
        "traefik.http.routers.vmagent.entrypoints=https",
        "traefik.http.routers.vmagent.rule=Host(`vmagent.service.consul`)",
      ]

      connect {
        sidecar_service {
          proxy {
            local_service_port = 8429
            upstreams {
              destination_name = "victoria-metrics"
              local_bind_port  = 8428
            }
            expose {
              path {
                path            = "/metrics"
                protocol        = "http"
                local_path_port = 8429
                listener_port   = "http"
              }
              path {
                path            = "/-/ready"
                protocol        = "http"
                local_path_port = 8429
                listener_port   = "health"
              }
            }
          }
        }
      }

      check {
        name     = "vmagent HTTP"
        type     = "http"
        port     = "health"
        path     = "/-/ready"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "vmagent" {
      driver = "docker"
      user   = "nobody"

      vault {
        policies = ["vmagent"]
      }

      resources {
        cpu        = 50
        memory     = 128
        memory_max = 256
      }

      config {
        image = "victoriametrics/vmagent:v${var.versions.vm}"

        args = [
          "-httpListenAddr=127.0.0.1:8429",
          "-promscrape.config=${NOMAD_TASK_DIR}/config.yml",
          "-promscrape.consulSDCheckInterval=10s",
          "-remoteWrite.url=http://localhost:8428/api/v1/write",
          "-remoteWrite.tmpDataPath=${NOMAD_ALLOC_DIR}/data/vmagent-queue",
          "-remoteWrite.maxDiskUsagePerURL=500MB",
        ]
      }

      template {
        data          = file("vmagent.yml")
        destination   = "local/config.yml"
        change_mode   = "signal"
        change_signal = "SIGHUP"
      }

      template {
        data = <<-EOH
        {{- with secret "pki/issue/internal" "common_name=vmagent.service.consul" -}}
        {{ .Data.issuing_ca }}{{ end }}
        EOH

        destination = "secrets/certs/CA.pem"
        change_mode = "restart"
        splay       = "5m"
      }
    }
  }
}
