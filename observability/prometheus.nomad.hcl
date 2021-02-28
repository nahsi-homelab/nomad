job "prometheus" {
  datacenters = ["syria"]

  group "prometheus" {

    network {
      port "http" {}
    }

    service {
      name = "prometheus"
      tags = ["observability"]
      port = "http"

      check {
        name     = "Prometheus HTTP"
        type     = "http"
        path     = "/prometheus/-/healthy"
        interval = "10s"
        timeout  = "2s"
      }
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
          "--web.listen-address=0.0.0.0:${NOMAD_PORT_http}",
          "--web.external-url=https://home.service.consul/prometheus",
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
    dc: "{{ env "node.datacenter" }}"

remote_write:
  - url: "https://home.service.consul/victoria-metrics/api/v1/write"
    tls_config:
      ca_file: "/secrets/ca.crt"

scrape_configs:
  - job_name: "prometheus"
    metrics_path: "/prmetheus/metrics"
    static_configs:
    - targets:
        - "localhost:{{ env "NOMAD_PORT_http" }}"
      labels:
        instance: "{{ env "attr.unique.hostname" }}"

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

      resources {
        cpu    = 300
        memory = 512
      }
    }
  }
}
