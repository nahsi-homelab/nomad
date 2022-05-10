variables {
  versions = {
    vm = "1.77.1"
  }
}

job "victoria-metrics" {
  datacenters = [
    "syria",
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
        dashboard = "wnf0q_kZk"
        alloc_id  = NOMAD_ALLOC_ID
      }

      tags = [
        "traefik.enable=true",
        "traefik.consulcatalog.connect=true",
        "traefik.http.routers.vm.entrypoints=https",
        "traefik.http.routers.vm.rule=Host(`victoria-metrics.service.consul`)",
        "traefik.http.middlewares.vm.basicauth.users=grafana:$apr1$t5jdWcQc$XW374MmpYV7bAwstzVOo3.,vmagent:$apr1$jX8.Ggk4$Y6VSTzJAt/fgtpNLoCrnT1",
        "traefik.http.routers.vm.middlewares=vm@consulcatalog",
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
        timeout  = "1s"
      }
    }

    volume "victoria-metrics" {
      type   = "host"
      source = "victoria-metrics"
    }

    task "victoria-metrics" {
      driver       = "docker"
      user         = "nobody"
      kill_timeout = "15s"

      vault {
        policies = ["victoria-metrics"]
      }

      resources {
        cpu        = 500
        memory     = 512
        memory_max = 1024
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

    ephemeral_disk {
      size = 600
      sticky = true
      migrate = true
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
        dashboard = "G7Z29GzMGz"
        alloc_id  = NOMAD_ALLOC_ID
      }

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.vmagent.entrypoints=https",
        "traefik.http.routers.vmagent.rule=Host(`vmagent.service.consul`)",
      ]

      check {
        name     = "vmagent HTTP"
        type     = "http"
        port     = "health"
        path     = "/-/ready"
        interval = "10s"
        timeout  = "1s"
      }
    }

    task "vmagent" {
      driver = "docker"
      user   = "nobody"

      vault {
        policies = ["vmagent"]
      }

      resources {
        cpu        = 200
        memory     = 128
        memory_max = 512
      }

      config {
        image = "victoriametrics/vmagent:v${var.versions.vm}"

        args = [
          "-httpListenAddr=0.0.0.0:${NOMAD_PORT_http}",
          "-envflag.enable",
          "-promscrape.config=${NOMAD_TASK_DIR}/config.yml",

          "-remoteWrite.tmpDataPath=${NOMAD_ALLOC_DIR}/data/vmagent-queue",
          "-remoteWrite.maxDiskUsagePerURL=500MB",

          "-remoteWrite.url=https://victoria-metrics.service.consul/api/v1/write",
          "-remoteWrite.tlsCAFile=/secrets/certs/CA.pem",
          "-remoteWrite.basicAuth.username=vmagent",
          "-remoteWrite.basicAuth.password=${VM_PASSWORD}",
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

      template {
        data = <<-EOH
        {{- with secret "secret/victoria-metrics/basicauth/vmagent" }}
        VM_PASSWORD={{ .Data.data.password }}
        {{- end }}
        EOH

        destination = "secrets/vm.env"
        env         = true
      }

      template {
        data = <<-EOH
        {{- with secret "secret/minio/prometheus" }}{{ .Data.data.token }}{{ end -}}
        EOH

        destination = "secrets/minio-token"
        change_mode = "restart"
        splay       = "5m"
      }
    }
  }
}
