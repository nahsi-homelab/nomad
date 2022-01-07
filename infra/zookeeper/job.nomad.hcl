variables {
  versions = {
    zookeeper = "3.7.0"
    promtail  = "2.4.1"
  }
}

job "zookeeper" {
  datacenters = [
    "syria",
    "asia",
    "pontus"
  ]
  namespace = "infra"

  constraint {
    distinct_property = meta.zoo_node_id
  }

  update {
    max_parallel = 1
    stagger      = "1m"
  }

  group "zookeeper" {
    count = 5
    network {
      port "client" {
        to     = 2181
        static = 2181
      }

      port "follower" {
        to     = 2888
        static = 2888
      }

      port "election" {
        to     = 3888
        static = 3888
      }

      port "admin" {
        to = 8080
      }

      port "metrics" {
        to = 7070
      }

      port "promtail" {
        to = 3000
      }
    }

    service {
      name = "zookeeper"
      port = "metrics"
      tags = ["metrics"]
    }

    service {
      name = "zookeeper-${meta.zoo_node_id}"
      port = "client"

      check {
        name    = "ZooKeeper ruok"
        task    = "zookeeper"
        type    = "script"
        command = "/bin/bash"
        args = [
          "-c",
          "[[ $(echo ruok|nc ${NOMAD_IP_client} ${NOMAD_PORT_client}) == imok ]] || exit 2"
        ]
        interval = "60s"
        timeout  = "1s"
      }
    }

    service {
      name = "promtail"
      port = "promtail"

      meta {
        sidecar_to = "zookeeper"
      }

      check {
        type     = "http"
        path     = "/ready"
        interval = "10s"
        timeout  = "2s"
      }
    }

    volume "zookeeper" {
      type   = "host"
      source = "zookeeper"
    }

    task "zookeeper" {
      driver = "docker"
      user   = "1001"

      vault {
        policies = [
          "zookeeper"
        ]
      }

      resources {
        cpu    = 300
        memory = 512
      }

      volume_mount {
        volume      = "zookeeper"
        destination = "/bitnami/zookeeper"
      }

      env {
        JVMFLAGS              = "-Xmx512m -Djava.security.auth.login.config=/secrets/jaas.conf"
        ALLOW_ANONYMOUS_LOGIN = "yes"

        ZOO_SERVER_ID    = meta.zoo_node_id
        ZOO_DATA_DIR     = "/bitnami/zookeeper/data"
        ZOO_DATA_LOG_DIR = "/bitnami/zookeeper/datalog"
      }

      config {
        image = "bitnami/zookeeper:${var.versions.zookeeper}"
        extra_hosts = [
          "zookeeper-${meta.zoo_node_id}.service.consul:0.0.0.0"
        ]

        ports = [
          "client",
          "follower",
          "election",
          "admin",
          "metrics"
        ]

        volumes = [
          "local/zoo.cfg:/opt/bitnami/zookeeper/conf/zoo.cfg"
        ]
      }

      template {
        data        = file("zoo.cfg")
        destination = "local/zoo.cfg"
        change_mode = "restart"
      }

      template {
        data        = file("jaas.conf")
        destination = "secrets/jaas.conf"
        change_mode = "restart"
      }
    }

    task "promtail" {
      driver = "docker"
      user   = "nobody"

      lifecycle {
        hook    = "poststart"
        sidecar = true
      }

      resources {
        cpu    = 50
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
        data        = file("promtail.yml")
        destination = "local/promtail.yml"
      }
    }
  }
}
