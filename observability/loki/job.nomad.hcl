job "loki" {

  datacenters = ["syria"]
  type        = "service"

  group "loki" {

    network {
      port "http" {
        static = 3100
      }
    }

    service {
      name = "loki"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.loki.rule=Host(`loki.service.consul`)",
        "traefik.http.routers.loki.tls=true"
      ]

      check {
        name     = "Loki HTTP"
        type     = "http"
        path     = "/ready"
        interval = "10s"
        timeout  = "2s"
      }
    }

    volume "loki" {
      type   = "host"
      source = "loki"
    }

    task "loki" {
      driver = "docker"
      user   = "nobody"

      volume_mount {
        volume      = "loki"
        destination = "/loki"
      }

      config {
        image = "grafana/loki:2.3.0"

        ports = [
          "http"
        ]

        args = [
          "-config.file=/local/loki.yml"
        ]
      }

      template {
        data = <<EOH
target: all
auth_enabled: false

server:
  http_listen_port: 3100

ingester:
  lifecycler:
    address: 127.0.0.1
    ring:
      kvstore:
        store: inmemory
      replication_factor: 1
    final_sleep: 0s
  chunk_idle_period: 5m
  chunk_retain_period: 30s

schema_config:
  configs:
  - from: 2021-09-04
    store: boltdb
    object_store: filesystem
    schema: v11
    index:
      prefix: index_
      period: 168h

storage_config:
  boltdb:
    directory: /loki/index

  filesystem:
    directory: /loki/chunks

limits_config:
  enforce_metric_name: false
  reject_old_samples: true
  reject_old_samples_max_age: 168h
EOH

        change_mode   = "signal"
        change_signal = "SIGHUP"
        destination   = "local/loki.yml"
      }
    }
  }
}
