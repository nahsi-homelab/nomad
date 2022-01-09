variables {
  versions = {
    redis = "6.2"
  }
}

job "redis-mail" {
  datacenters = [
    "syria",
    "asia",
    "pontus"
  ]
  namespace = "infra"

  update {
    max_parallel = 1
    stagger      = "1m"
  }

  group "master" {
    network {
      port "redis" {
        to     = 6379
        static = 6379
      }
    }

    service {
      name = "redis-mail-master"
      port = "redis"
    }

    volume "master" {
      type   = "host"
      source = "redis-mail-master"
    }

    task "redis-master" {
      driver = "docker"
      user   = "nobody"

      vault {
        policies = ["redis-mail"]
      }

      volume_mount {
        volume      = "master"
        destination = "/data"
      }

      resources {
        cpu    = 300
        memory = 128
      }

      config {
        image   = "redis:${var.versions.redis}-alpine"
        ports   = ["redis"]
        command = "redis-server"
        args    = [
          "/local/redis.conf",
          "replica-priority", "200"
        ]
      }

      template {
        data        = file("redis.conf")
        destination = "/local/redis.conf"
        change_mode = "restart"
        splay       = "1m"
      }

      template {
        data        = file("auth.conf")
        destination = "/secrets/auth.conf"
        change_mode = "restart"
        splay       = "1m"
      }

      template {
        data        = file("users.acl")
        destination = "/secrets/users.acl"
        change_mode = "restart"
        splay       = "1m"
      }

      template {
        data = <<-EOH
        {{- with secret "pki/issue/internal" "common_name=redis-mail-master.service.consul" -}}
        {{ .Data.issuing_ca }}{{ end }}
        EOH

        destination = "secrets/certs/CA.pem"
        change_mode = "restart"
        splay       = "1m"
      }

      template {
        data = <<-EOH
        {{- with secret "pki/issue/internal" "common_name=redis-mail-master.service.consul" -}}
        {{ .Data.private_key }}{{ end }}
        EOH

        destination = "secrets/certs/key.pem"
        change_mode = "restart"
        splay       = "1m"
      }

      template {
        data = <<-EOH
        {{- with secret "pki/issue/internal" "common_name=redis-mail-master.service.consul" -}}
        {{ .Data.certificate }}{{ end }}
        EOH

        destination = "secrets/certs/cert.pem"
        change_mode = "restart"
        splay       = "1m"
      }
    }
  }

  group "replicas" {
    count = 2
    network {
      port "redis" {}
    }

    service {
      name = "redis-mail-replica"
      port = "redis"
    }

    service {
      name = "redis-mail-replica-${NOMAD_ALLOC_INDEX}"
      port = "redis"
    }

    volume "replica" {
      type   = "host"
      source = "redis-mail-replica"
    }

    task "replica" {
      driver = "docker"
      user   = "nobody"

      vault {
        policies = ["redis-mail"]
      }

      volume_mount {
        volume      = "replica"
        destination = "/data"
      }

      resources {
        cpu    = 300
        memory = 128
      }

      config {
        image   = "redis:${var.versions.redis}-alpine"
        ports   = ["redis"]
        command = "redis-server"
        args = [
          "/local/redis.conf",
          "replicaof", "redis-mail-master.service.consul", "6379"
        ]
      }

      template {
        data        = file("redis.conf")
        destination = "/local/redis.conf"
        change_mode = "restart"
        splay       = "1m"
      }

      template {
        data        = file("auth.conf")
        destination = "/secrets/auth.conf"
        change_mode = "restart"
        splay       = "1m"
      }

      template {
        data        = file("users.acl")
        destination = "/secrets/users.acl"
        change_mode = "restart"
        splay       = "1m"
      }

      template {
        data = <<-EOH
        {{- with secret "pki/issue/internal" "common_name=redis-mail-replica.service.consul" -}}
        {{ .Data.issuing_ca }}{{ end }}
        EOH

        destination = "secrets/certs/CA.pem"
        change_mode = "restart"
        splay       = "1m"
      }

      template {
        data = <<-EOH
        {{- with secret "pki/issue/internal" "common_name=redis-mail-replica.service.consul" -}}
        {{ .Data.private_key }}{{ end }}
        EOH

        destination = "secrets/certs/key.pem"
        change_mode = "restart"
        splay       = "1m"
      }

      template {
        data = <<-EOH
        {{- with secret "pki/issue/internal" "common_name=redis-mail-replica.service.consul" -}}
        {{ .Data.certificate }}{{ end }}
        EOH

        destination = "secrets/certs/cert.pem"
        change_mode = "restart"
        splay       = "1m"
      }
    }
  }
}
