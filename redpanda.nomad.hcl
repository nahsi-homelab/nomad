variables {
  versions = {
    redpanda = "21.9.4"
  }
}

job "redpanda" {
  datacenters = ["syria", "asia"]
  type        = "service"

  update {
    max_parallel = 1
    min_healthy_time = "1m"
  }

  group "redpanda" {
    count = 3

    constraint {
      distinct_hosts = true
    }

    network {
      port "rpc" {
        to = 33145
        static = 33145
      }

      port "kafka" {
        to = 9092
        static = 9092
      }

      port "pandaproxy" {
        to = 8082
        static = 8082
      }

      port "admin" {
        to = 9644
      }
    }

    service {
      name = "redpanda"
      port = "admin"

      tags = [
        "node=${meta.redpanda_node_id}"
      ]

      check {
        type = "http"
        port = "admin"
        path = "/v1/status/ready"
        interval = "30s"
        timeout = "2s"
      }
    }

    service {
      name = "redpanda-${meta.redpanda_node_id}"
      port = "admin"

      check {
        type = "http"
        port = "admin"
        path = "/v1/status/ready"
        interval = "30s"
        timeout = "2s"
      }
    }

    volume "redpanda" {
      type = "host"
      source = "redpanda"
    }

    task "redpanda" {
      driver = "docker"
      user = "101"

      volume_mount {
        volume = "redpanda"
        destination = "/var/lib/redpanda/"
      }

      config {
        image = "docker.vectorized.io/vectorized/redpanda:v${var.versions.redpanda}"

        ports = [
          "rpc",
          "kafka",
          "pandaproxy",
          "admin"
        ]

        command = "redpanda"

        args = [
          "start",
          "--config=local/redpanda.yaml",
          "--node-id", meta.redpanda_node_id,
          "--check=false",
          "--smp=2", "--memory=4G", "--reserve-memory=0M",
          "--seeds=${meta.redpanda_root}"
        ]
      }

      template {
        data = <<EOH
pandaproxy:
  pandaproxy_api:
    - address: 0.0.0.0
      port: 8082
  advertised_pandaproxy_api:
    - address: redpanda-{{ env "meta.redpanda_node_id" }}.service.consul
      port: 8082

redpanda:
  admin:
    - address: 0.0.0.0
      port: 9644

  kafka_api:
    - address: 0.0.0.0
      port: 9092
  advertised_kafka_api:
    - address: redpanda-{{ env "meta.redpanda_node_id" }}.service.consul
      port: 9092

  rpc_server:
    address: 0.0.0.0
    port: 33145
  advertised_rpc_api:
    address: redpanda-{{ env "meta.redpanda_node_id" }}.service.consul
    port: 33145
  auto_create_topics_enabled: false
  data_directory: /var/lib/redpanda/data
  developer_mode: true

rpk:
  coredump_dir: /var/lib/redpanda/coredump
  enable_memory_locking: false
  enable_usage_stats: true
  overprovisioned: true
  tune_aio_events: false
  tune_ballast_file: false
  tune_clocksource: false
  tune_coredump: false
  tune_cpu: false
  tune_disk_irq: false
  tune_disk_nomerges: false
  tune_disk_scheduler: false
  tune_disk_write_cache: false
  tune_fstrim: false
  tune_network: false
  tune_swappiness: false
  tune_transparent_hugepages: false
EOH

        destination = "local/redpanda.yaml"
        perms = "777"
      }

      resources {
        cpu = 2000
        memory = 4096
      }
    }
  }
}
