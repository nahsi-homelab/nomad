variables {
  versions = {
    redis = "6.2"
  }
}

job "redis-sentinel" {
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

  group "sentinels" {
    count = 3
    constraint {
      distinct_property = meta.sentinel_node_id
    }

    network {
      port "sentinel" {
        to     = 26379
        static = 26379
      }
    }

    volume "sentinel" {
      type   = "host"
      source = "redis-sentinel"
    }

    service {
      name = "redis-sentinel-${NOMAD_ALLOC_INDEX}"
      port = "sentinel"
    }

    service {
      name = "redis-sentinel"
      port = "sentinel"
    }

    task "sentinel" {
      driver = "docker"

      vault {
        policies = ["redis-sentinel"]
      }

      resources {
        cpu    = 300
        memory = 128
      }

      volume_mount {
        volume      = "sentinel"
        destination = "/data"
      }

      config {
        image   = "redis:${var.versions.redis}-alpine"
        ports   = ["sentinel"]
        command = "redis-sentinel"
        args    = ["/local/sentinel.conf"]
      }

      template {
        data        = file("sentinel.conf")
        destination = "/local/sentinel.conf"
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
        {{- with secret "pki/issue/internal" "common_name=sentinel.service.consul" -}}
        {{ .Data.issuing_ca }}{{ end }}
        EOH

        destination = "secrets/certs/CA.pem"
        change_mode = "restart"
        splay       = "1m"
      }

      template {
        data = <<-EOH
        {{- with secret "pki/issue/internal" "common_name=sentinel.service.consul" -}}
        {{ .Data.private_key }}{{ end }}
        EOH

        destination = "secrets/certs/key.pem"
        change_mode = "restart"
        splay       = "1m"
      }

      template {
        data = <<-EOH
        {{- with secret "pki/issue/internal" "common_name=sentinel.service.consul" -}}
        {{ .Data.certificate }}{{ end }}
        EOH

        destination = "secrets/certs/cert.pem"
        change_mode = "restart"
        splay       = "1m"
      }
    }
  }
}
