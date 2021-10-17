variables {
  versions = {
    kafka = "2.8.1"
    promtail = "2.3.0"
  }
}

job "kafka" {
  datacenters = ["syria", "asia"]
  namespace   = "infra"
  type        = "service"

  update {
    max_parallel = 1
    stagger      = "1m"
    auto_revert  = true
  }

  group "kafka" {
    count = 3

    network {
      port "client" {
        to = 9092
        static = 9092
      }

      port "internal" {
        to = 9093
        static = 9093
      }

      port "promtail" {
        to = 3000
      }
    }

    volume "kafka" {
      type = "host"
      source = "kafka"
    }

    task "kafka" {
      driver = "docker"
      user = "1001"

      vault {
        policies = ["kafka"]
      }

      service {
        name = "kafka"
        port = "client"
        address_mode = "host"
      }

      service {
        name = "kafka-${meta.kafka_node_id}"
        port = "client"
        address_mode = "host"
      }

      resources {
        cpu = 300
        memory = 1024
      }

      volume_mount {
        volume = "kafka"
        destination = "/bitnami/kafka"
      }

      env {
        JVMFLAGS = "-Xmx1024m"
        KAFKA_OPTS="-Djava.security.auth.login.config=/secrets/jaas.conf"
        ALLOW_PLAINTEXT_LISTENER="yes"
      }

      config {
        image = "bitnami/kafka:${var.versions.kafka}"
        hostname = "kafka-${meta.kafka_node_id}"
        extra_hosts = [
          "kafka-${meta.kafka_node_id}.service.consul:0.0.0.0"
        ]

        ports = [
          "client",
          "internal"
        ]

        volumes = [
          "local/server.properties:/bitnami/kafka/config/server.properties"
        ]
      }

      template {
        data = file("server.properties")
        destination = "local/server.properties"
        change_mode = "restart"
        splay = "1m"
      }

      template {
        data = file("jaas.conf")
        destination = "secrets/jaas.conf"
        change_mode = "restart"
        splay = "1m"
      }
    }

    task "promtail" {
      driver = "docker"
      user = "nobody"

      lifecycle {
        hook    = "poststart"
        sidecar = true
      }

      service {
        name = "promtail"
        port = "promtail"
        tags = ["service=kafka"]
        address_mode = "host"

        check {
          type     = "http"
          path     = "/ready"
          interval = "10s"
          timeout  = "2s"
        }
      }

      resources {
        cpu = 50
        memory = 128
      }

      config {
        image = "grafana/promtail:${var.versions.promtail}"

        args = [
          "-config.file=local/promtail.yml"
        ]

        ports = [
          "promtail"
        ]
      }

      template {
        data = file("promtail.yml")
        destination = "local/promtail.yml"
      }
    }
  }
}
