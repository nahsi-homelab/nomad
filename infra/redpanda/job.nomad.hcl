variables {
  versions = {
    redpanda = "21.9.4"
  }
}

job "redpanda" {
  datacenters = ["syria", "asia"]
  namespace   = "infra"
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
        data = file("redpanda.yml")
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
