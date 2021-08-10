job "prometheus" {
  datacenters = ["syria"]
  type        = "service"

  group "prometheus" {
    network {
      port "http" {
        to = 9090
        static = 9090
      }
    }

    service {
      name = "prometheus"
      port = "http"

      check {
        name     = "Prometheus HTTP"
        type     = "http"
        path     = "/-/healthy"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "prometheus" {
      driver = "docker"

      user = "nobody"

      config {
        image = "prom/prometheus:v2.28.1"

        ports = [
          "http"
        ]

        extra_hosts = [
          "host.docker.internal:host-gateway"
        ]

        mount {
          type = "volume"
          target = "/data"
          source = "prometheus"
        }

        args = [
          "--web.listen-address=0.0.0.0:${NOMAD_PORT_http}",
          "--config.file=/local/prometheus.yml",
          "--storage.tsdb.retention.time=90d",
          "--web.enable-lifecycle"
        ]
      }

      template {
        data = <<EOH
---
global:
  scrape_interval:     15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: "prometheus"
    metrics_path: "/metrics"
    static_configs:
    - targets:
        - "localhost:{{ env "NOMAD_PORT_http" }}"
      labels:
        instance: "{{ env "attr.unique.hostname" }}"

  - job_name: "telegraf"
    consul_sd_configs:
      - server: "http://host.docker.internal:8500"
        datacenter: "oikumene"
        services:
          - "telegraf"
    relabel_configs:
      - source_labels: ["__meta_consul_node"]
        target_label: "instance"

  - job_name: "consul"
    metrics_path: "/v1/agent/metrics"
    params:
      format: ["prometheus"]
    consul_sd_configs:
      - server: "http://host.docker.internal:8500"
        datacenter: "oikumene"
        services:
          - "telegraf"
    relabel_configs:
      - source_labels: ["__address__"]
        target_label: "__address__"
        regex: "(.*):.*"
        replacement: "$1:8500"
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
