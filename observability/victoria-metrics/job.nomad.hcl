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
    }

    service {
      name = "victoria-metrics"
      port = 8428

      meta {
        alloc_id = NOMAD_ALLOC_ID
      }

      connect {
        sidecar_service {}
      }

      check {
        expose   = true
        name     = "VictoriaMetrics HTTP"
        type     = "http"
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
    constraint {
      distinct_property = node.datacenter
    }

    ephemeral_disk {
      size   = 500
      sticky = true
    }

    network {
      mode = "bridge"
      port "http" {
        to = 8429
      }
    }

    service {
      name = "vmagent"
      port = "http"

      meta {
        alloc_id = NOMAD_ALLOC_ID
      }

      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "victoria-metrics"
              local_bind_port  = 8428
            }
          }
        }
      }

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.vmagent.entrypoints=https",
        "traefik.http.routers.vmagent.rule=Host(`vmagent.service.consul`)",
      ]

      check {
        name     = "vmagent HTTP"
        type     = "http"
        path     = "/-/ready"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "vmagent" {
      driver = "docker"
      user   = "nobody"

      resources {
        cpu        = 50
        memory     = 128
        memory_max = 256
      }

      config {
        image = "victoriametrics/vmagent:v${var.versions.vm}"

        ports = [
          "http"
        ]

        args = [
          "-promscrape.config=${NOMAD_TASK_DIR}/config.yml",
          "-remoteWrite.tmpDataPath=${NOMAD_ALLOC_DIR}/data/vmagent-queue",
          "-remoteWrite.maxDiskUsagePerURL=500MB",

          "-remoteWrite.url=http://localhost:8428/api/v1/write",
        ]
      }

      template {
        data          = file("vmagent.yml")
        destination   = "local/config.yml"
        change_mode   = "signal"
        change_signal = "SIGHUP"
      }
    }
  }
}
