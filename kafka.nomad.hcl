variables {
  versions = {
    kafka = "7.1.0-30"
  }
}

job "kafka" {
  datacenters = ["syria"]
  type        = "service"

  update {
    max_parallel = 1
    min_healthy_time = "1m"
  }

  group "kafka" {
    count = 1

    network {
      port "kafka" {
        to = 9092
        static = 9092
      }
    }

    service {
      name = "kafka"
      port = "kafka"

      check {
        type = "tcp"
        port = "kafka"
        interval = "30s"
        timeout = "2s"
        initial_status = "passing"
      }
    }

    task "kakfa" {
      driver = "docker"

      env {
KAFKA_BROKER_ID="1"
KAFKA_LISTENERS="PLAINTEXT://kafka.service.consul:9092"
KAFKA_ADVERTISED_LISTENERS="PLAINTEXT://kafka.service.consul:9092"

NODE_ID="1"
PROCESS_ROLES="broker,controller"
LISTENERS="CONTROLLER://kafka.service.consul:9093"
CONTROLLER_QUORUM_VOTERS="1@kafka.service.consul:9093"
BOOTSTRAP_SERVERS="kafka.service.consul:9092"
}

      config {
        image = "kafka-cp:v${var.versions.kafka}"

        ports = [
          "kafka"
        ]
      }

      resources {
        cpu = 100
        memory = 512
      }
    }
  }
}
