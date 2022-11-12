variables {
  versions = {
    keydb    = "x86_64_v6.3.1"
    exporter = "1.37.0"
  }
}

job "keydb" {
  datacenters = [
    "syria",
  ]
  namespace = "infra"

  group "keydb" {
    count = 2

    update {
      max_parallel = 1
      stagger      = "1m"
    }

    network {
      port "redis" {
        to     = 6379
        static = 6379
      }
    }

    vault {
      policies = ["keydb"]
    }

    volume "keydb" {
      type   = "host"
      source = "keydb"
    }

    service {
      name = "keydb"
      port = "redis"
    }

    service {
      name = "keydb-${node.unique.name}"
      port = "redis"
    }

    task "keydb" {
      driver = "docker"
      user   = "nobody"

      volume_mount {
        volume      = "keydb"
        destination = "/data"
      }

      config {
        image = "eqalpha/keydb:${var.versions.keydb}"
        ports = [
          "redis",
        ]

        command = "keydb-server"
        args = [
          "/local/redis.conf",
          "--replicaof", meta.keydb_replica, NOMAD_PORT_redis,
        ]
      }

      template {
        data        = file("redis/redis.conf")
        destination = "/local/redis.conf"
      }

      template {
        data        = file("redis/auth.conf")
        destination = "/secrets/auth.conf"
      }

      resources {
        cpu        = 100
        memory     = 64
        memory_max = 128
      }
    }
  }

  group "redis-exporter" {
    network {
      port "exporter" {
        to = 9121
      }
    }

    service {
      name = "redis-exporter"
      port = "exporter"

      meta {
        target = "keydb"
      }

      check {
        name     = "redis-exporter"
        path     = "/"
        type     = "http"
        interval = "10s"
        timeout  = "1s"
      }
    }

    task "redis-exporter" {
      driver = "docker"

      vault {
        policies = ["redis-exporter"]
      }

      config {
        image = "oliver006/redis_exporter:v${var.versions.exporter}"

        ports = [
          "exporter",
        ]
      }

      template {
        data = <<-EOH
        REDIS_ADDR=keydb.service.consul
        {{ with secret "secret/keydb/users/default" }}
        REDIS_PASSWORD={{ .Data.data.password }}
        {{- end }}
        EOH

        destination = "secrets/redis.env"
        env         = true
      }

      resources {
        cpu        = 10
        memory     = 32
        memory_max = 64
      }
    }
  }
}
