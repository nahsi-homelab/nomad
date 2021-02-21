job "prometheus" {
  datacenters = ["syria"]

  group "prometheus" {

    network {
      port "web_ui" {
        to = 9090
      }
    }

    service {
      name = "prometheus"
      port = "web_ui"

      check {
        type     = "http"
        path     = "/-/healthy"
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
          "web_ui"
        ]

        dns = [
          "10.88.0.1"
        ]

        args = [
          "--config.file=/etc/prometheus/config/prometheus.yml",
          "--storage.tsdb.path=/prometheus",
          "--web.console.libraries=/usr/share/prometheus/console_libraries",
          "--web.console.templates=/usr/share/prometheus/consoles",
        ]

        volumes = [
          "local/config:/etc/prometheus/config",
          "/mnt/apps/prometheus:/prometheus"
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
    consul_sd_configs:
      - server: "https://consul.service.consul:8501"
        datacenter: "syria"
        services:
          - "prometheus"
    relabel_configs:
      - source_labels: ["__meta_consul_service"]
        target_label: "job"
      - source_labels: ["__meta_consul_node"]
        target_label: "instance"

  - job_name: "telegraf"
    consul_sd_configs:
      - server: "https://consul.service.consul:8501"
        datacenter: "syria"
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
        destination   = "local/config/prometheus.yml"
      }

      resources {
        cpu    = 1000
        memory = 4096
      }
    }
  }
}
