job "prometheus" {
  datacenters = ["syria"]

  group "prometheus" {

    network {
      port "http" {}
    }

    task "prometheus" {
      driver = "podman"

      user = "nobody"

      config {
        image = "docker://prom/prometheus:v2.25.0"

        ports = [
          "http"
        ]

        dns = ["10.88.0.1"]

        args = [
          "--web.listen-address=:${NOMAD_PORT_http}",
          "--web.external-url=https://home.service.consul/prometheus",
          "--web.route-prefix=/",
          "--config.file=/local/prometheus.yml",
          "--storage.tsdb.path=/prometheus",
          "--storage.tsdb.retention.time=5d",
          "--web.enable-lifecycle",
          "--web.console.libraries=/usr/share/prometheus/console_libraries",
          "--web.console.templates=/usr/share/prometheus/consoles"
        ]

        volumes = [
          "/mnt/apps/prometheus:/prometheus"
        ]
      }

      template {
        data = <<EOH
{{ with secret "pki/internal/cert/ca" }}{{- .Data.certificate }}{{ end }}
EOH

        destination = "secrets/ca.crt"
      }

      template {
        data = <<EOH
---
global:
  scrape_interval:     15s
  evaluation_interval: 15s
  external_labels:
    dc: "${node.datacenter}"

remote_write:
  - url: "https://home.service.consul/victoriametrics/api/v1/write"
    tls_config:
      ca_file: "/secrets/ca.crt"

scrape_configs:
  - job_name: "prometheus"
    metrics_path: "/prometheus/metrics"
    static_configs:
    - targets:
        - "localhost:${NOMAD_PORT_http}"

  - job_name: "telegraf"
    consul_sd_configs:
      - server: "https://consul.service.consul:8501"
        datacenter: "syria"
        tls_config:
          ca_file: "/secrets/ca.crt"
        services:
          - "telegraf"
    relabel_configs:
      - source_labels: ["__meta_consul_service"]
        target_label: "job"
      - source_labels: ["__meta_consul_node"]
        target_label: "instance"
EOH

        change_mode   = "signal"
        change_signal = "SIGHUP"
        destination   = "local/prometheus.yml"
      }

      service {
        name = "prometheus"
        tags = ["observability"]
        port = "http"

        check {
          name     = "Prometheus HTTP"
          type     = "http"
          path     = "/-/healthy"
          interval = "10s"
          timeout  = "2s"
        }
      }

      resources {
        cpu    = 300
        memory = 512
      }
    }
  }
}
