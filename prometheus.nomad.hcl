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

    volume "prometheus" {
      type = "host"
      source = "prometheus"
    }

    task "prometheus" {
      driver = "docker"
      user = "nobody"

      volume_mount {
        volume = "prometheus"
        destination = "/var/lib/prometheus"
      }

      config {
        image = "prom/prometheus:v2.30.0"

        ports = [
          "http"
        ]

        extra_hosts = [
          "host.docker.internal:host-gateway"
        ]

        args = [
          "--web.listen-address=0.0.0.0:${NOMAD_PORT_http}",
          "--config.file=/local/prometheus.yml",
          "--storage.tsdb.retention.time=1y",
          "--storage.tsdb.path=/var/lib/prometheus",
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
      - source_labels: ["__meta_consul_tags"]
        regex: ".*,([^=]+)=([^,]+),.*"
        replacement: "$2"
        target_label: "$1"

  - job_name: "promtail"
    consul_sd_configs:
      - server: "http://host.docker.internal:8500"
        datacenter: "oikumene"
        services:
          - "promtail"
    relabel_configs:
      - source_labels: ["__meta_consul_node"]
        target_label: "instance"

  - job_name: "loki"
    consul_sd_configs:
      - server: "http://host.docker.internal:8500"
        datacenter: "oikumene"
        services:
          - "loki"
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

  - job_name: "unpoller"
    consul_sd_configs:
      - server: "http://host.docker.internal:8500"
        datacenter: "oikumene"
        services:
          - "unpoller"
    relabel_configs:
      - source_labels: ["__meta_consul_node"]
        target_label: "instance"

  - job_name: "transmission-exporter"
    consul_sd_configs:
      - server: "http://host.docker.internal:8500"
        datacenter: "oikumene"
        services:
          - "transmission-exporter"
    relabel_configs:
      - source_labels: ["__meta_consul_node"]
        target_label: "instance"

  - job_name: "jellyfin"
    consul_sd_configs:
      - server: "http://host.docker.internal:8500"
        datacenter: "oikumene"
        services:
          - "jellyfin-app"
    relabel_configs:
      - source_labels: ["__meta_consul_node"]
        target_label: "instance"

  - job_name: "postgres"
    consul_sd_configs:
      - server: "http://host.docker.internal:8500"
        datacenter: "oikumene"
        services:
          - "postgres-exporter"
    relabel_configs:
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
