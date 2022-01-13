variables {
  versions = {
    wildduck = "1.34.0"
    haraka   = "latest"
    zone-mta = "latest"

    redis = "6.2"
    resec = "latest"
  }
}

job "mail" {
  datacenters = [
    "syria",
  ]
  namespace = "services"

  group "wildduck" {
    count = 2

    vault {
      policies = ["wildduck"]
    }

    network {
      port "api" {
        to     = 8080
        static = 8888
      }
    }

    service {
      name = "wildduck"
      port = "api"

      tags = [
        "ingress.enable=true",
        "ingress.tcp.routers.wildduck-imap.entrypoints=imap",
        "ingress.tcp.routers.wildduck-imap.rule=HostSNI(`mail.nahsi.dev`)",
        "ingress.tcp.routers.wildduck-imap.tls=true",
      ]
    }

    task "wildduck" {
      driver = "docker"

      resources {
        cpu    = 500
        memory = 256
      }

      env {
        WILDDUCK_CONFIG = "/local/wildduck/config/default.toml"
      }

      config {
        image = "nodemailer/wildduck:v${var.versions.wildduck}"

        ports = [
          "api"
        ]
      }

      dynamic "template" {
        for_each = fileset(".", "wildduck/secrets/**")

        content {
          data        = file(template.value)
          destination = "secrets/${template.value}"
          change_mode = "noop"
        }
      }

      dynamic "template" {
        for_each = fileset(".", "wildduck/config/**")

        content {
          data        = file(template.value)
          destination = "local/${template.value}"
          change_mode = "noop"
        }
      }

      # CA
      template {
        data = <<-EOH
        {{- with secret "pki/issue/internal" "ttl=30d" "common_name=*.service.consul" -}}
        {{ .Data.issuing_ca }}{{ end }}
        EOH

        destination = "secrets/certs/CA.pem"
        change_mode = "restart"
        splay       = "1m"
      }

      # bundle
      template {
        data = <<-EOH
        {{- with secret "pki/issue/internal" "ttl=30d" "common_name=wildduck.service.consul" -}}
        {{ .Data.private_key }}
        {{ .Data.certificate }}{{ end }}
        EOH

        destination = "secrets/certs/bundle.pem"
        change_mode = "restart"
        splay       = "1m"
      }
    }
  }

  group "wildduck-webmail" {
    count = 2

    vault {
      policies = ["wildduck-webmail"]
    }

    network {
      port "http" {
        to = 3000
      }
    }

    service {
      name = "wildduck-webmail"
      port = "http"

      tags = [
        "ingress.enable=true",
        "ingress.http.routers.wildduck-webmail.entrypoints=https",
        "ingress.http.routers.wildduck-webmail.rule=Host(`mail.nahsi.dev`)",
        "ingress.http.routers.wildduck-webmail.tls=true",
      ]
    }

    task "wildduck-webmail" {
      driver = "docker"

      resources {
        cpu    = 500
        memory = 256
      }

      config {
        image = "nodemailer/wildduck-webmail:latest"

        ports = [
          "http"
        ]

        entrypoint = ["node"]
        command    = "server.js"
        args       = ["--config=/local/default.toml"]
      }

      template {
        data        = file("wildduck-webmail/dbs.toml")
        destination = "secrets/config/dbs.toml"
        change_mode = "noop"
      }

      template {
        data        = file("wildduck-webmail/default.toml")
        destination = "local/default.toml"
        change_mode = "noop"
      }

      # CA
      template {
        data = <<-EOH
        {{- with secret "pki/issue/internal" "ttl=30d" "common_name=wildduck-webmail.service.consul" -}}
        {{ .Data.issuing_ca }}{{ end }}
        EOH

        destination = "secrets/certs/CA.pem"
        change_mode = "restart"
        splay       = "1m"
      }

      # bundle
      template {
        data = <<-EOH
        {{- with secret "pki/issue/internal" "ttl=30d" "common_name=wildduck-webmail.service.consul" -}}
        {{ .Data.private_key }}
        {{ .Data.certificate }}{{ end }}
        EOH

        destination = "secrets/certs/bundle.pem"
        change_mode = "restart"
        splay       = "1m"
      }
    }
  }

  group "haraka" {
    count = 1

    vault {
      policies = ["haraka"]
    }

    network {
      port "smtp" {
        to           = 25
        static       = 25
        host_network = "public"
      }
    }

    service {
      name = "haraka"
      port = "smtp"
    }

    task "haraka" {
      driver = "docker"

      resources {
        cpu    = 500
        memory = 256
      }

      env {
        NODE_CLUSTER_SCHED_POLICY = "none"
        HARAKA_HOME               = "/local/haraka"
      }

      config {
        image = "nahsihub/haraka-wildduck:${var.versions.haraka}"

        ports = [
          "smtp"
        ]
      }

      dynamic "template" {
        for_each = fileset(".", "haraka/**")

        content {
          data        = file(template.value)
          destination = "local/${template.value}"
          change_mode = "noop"
        }
      }

      # CA
      template {
        data = <<-EOH
        {{- with secret "pki/issue/internal" "ttl=30d" "common_name=*.service.consul" -}}
        {{ .Data.issuing_ca }}{{ end }}
        EOH

        destination = "secrets/certs/CA.pem"
        change_mode = "restart"
        splay       = "1m"
      }

      # bundle
      template {
        data = <<-EOH
        {{- with secret "pki/issue/internal" "ttl=30d" "common_name=haraka.service.consul" -}}
        {{ .Data.private_key }}
        {{ .Data.certificate }}{{ end }}
        EOH

        destination = "secrets/certs/bundle.pem"
        change_mode = "restart"
        splay       = "1m"
      }

      template {
        data = <<-EOH
        {{- with secret "secret/certificate" -}}
        {{ .Data.data.ca_bundle }}{{ end }}
        EOH

        destination = "secrets/starttls/cert.pem"
        change_mode = "restart"
        splay       = "1m"
      }

      template {
        data = <<-EOH
        {{- with secret "secret/certificate" -}}
        {{ .Data.data.key }}{{ end }}
        EOH

        destination = "secrets/starttls/key.pem"
        change_mode = "restart"
        splay       = "1m"
      }
    }
  }

  group "zone-mta" {
    count = 1

    vault {
      policies = ["zone-mta"]
    }

    network {
      port "api" {}
      port "smtp" {
        to = 587
      }
    }

    service {
      name = "zone-mta"
      port = "api"
    }

    task "zone-mta" {
      driver = "docker"

      resources {
        cpu        = 500
        memory     = 256
        memory_max = 350
      }

      env {
        NODE_CLUSTER_SCHED_POLICY = "none"
        ZONEMTA_CONFIG_DIR        = "/local/zone-mta/config"
      }

      config {
        image = "nahsihub/zone-mta-wildduck:${var.versions.zone-mta}"

        ports = [
          "api",
          "smtp"
        ]
      }

      dynamic "template" {
        for_each = fileset(".", "zone-mta/secrets/**")

        content {
          data        = file(template.value)
          destination = "secrets/${template.value}"
          change_mode = "noop"
        }
      }

      dynamic "template" {
        for_each = fileset(".", "zone-mta/config/**")

        content {
          data        = file(template.value)
          destination = "local/${template.value}"
          change_mode = "noop"
        }
      }

      # CA
      template {
        data = <<-EOH
        {{- with secret "pki/issue/internal" "ttl=30d" "common_name=*.service.consul" -}}
        {{ .Data.issuing_ca }}{{ end }}
        EOH

        destination = "secrets/certs/CA.pem"
        change_mode = "restart"
        splay       = "1m"
      }

      # bundle
      template {
        data = <<-EOH
        {{- with secret "pki/issue/internal" "ttl=30d" "common_name=zone-mta.service.consul" -}}
        {{ .Data.private_key }}
        {{ .Data.certificate }}{{ end }}
        EOH

        destination = "secrets/certs/bundle.pem"
        change_mode = "restart"
        splay       = "1m"
      }

      template {
        data = <<-EOH
        {{- with secret "secret/mail" -}}
        {{ .Data.data.dkin }}{{ end }}
        EOH

        destination = "secrets/dkim.pem"
        change_mode = "restart"
        splay       = "1m"
      }
    }
  }

  group "redis" {
    count = 2
    update {
      max_parallel = 1
      stagger      = "1m"
    }

    network {
      mode = "bridge"
      port "redis" {
        to     = 6379
        static = 6379
      }

      port "resec" {
        to = 8080
      }
    }

    vault {
      policies = ["redis-mail"]
    }

    volume "mail" {
      type   = "host"
      source = "redis-mail"
    }

    task "redis" {
      driver = "docker"
      user   = "nobody"

      volume_mount {
        volume      = "mail"
        destination = "/data"
      }

      resources {
        cpu    = 100
        memory = 64
      }

      config {
        image   = "redis:${var.versions.redis}-alpine"
        ports   = ["redis"]
        command = "redis-server"
        args = [
          "/local/redis.conf"
        ]
      }

      template {
        data        = file("redis/redis.conf")
        destination = "/local/redis.conf"
        change_mode = "restart"
        splay       = "1m"
      }

      template {
        data        = file("redis/auth.conf")
        destination = "/secrets/auth.conf"
        change_mode = "restart"
        splay       = "1m"
      }

      template {
        data        = file("redis/users.acl")
        destination = "/secrets/users.acl"
        change_mode = "restart"
        splay       = "1m"
      }
    }

    task "resec" {
      driver = "docker"

      resources {
        cpu    = 100
        memory = 64
      }

      service {
        name = "resec"
        port = "resec"

        check {
          name     = "Redis readiness"
          type     = "http"
          path     = "/health"
          interval = "20s"
          timeout  = "2s"
        }
      }

      env {
        CONSUL_HTTP_ADDR    = "http://${attr.unique.network.ip-address}:8500"
        CONSUL_SERVICE_NAME = "redis-mail"
        CONSUL_LOCK_KEY     = "resec/mail/.lock"
        MASTER_TAGS         = "master"
        SLAVE_TAGS          = "replica"
        REDIS_ADDR          = "127.0.0.1:6379"
        ANNOUNCE_ADDR       = "${NOMAD_ADDR_redis}"
        STATE_SERVER        = "true"
      }

      config {
        image = "nahsihub/resec:${var.versions.resec}"
        ports = ["resec"]
      }

      template {
        data = <<-EOH
        REDIS_PASSWORD={{ with secret "secret/data/redis/mail/users/default" }}{{ .Data.data.password }}{{ end }}
        EOH

        destination = "secrets/password"
        env         = true
        change_mode = "restart"
        splay       = "1m"
      }
    }
  }
}
