job "mail" {
  datacenters = [
    "syria",
    "asia"
  ]

  group "redis" {
    network {
      port "db" {
        to     = 6379
        static = 6379
      }
    }

    service {
      name = "redis"
      port = "db"
    }

    task "redis" {
      driver = "docker"

      config {
        image = "redis:3.2"
        ports = ["db"]
      }

      resources {
        cpu    = 500
        memory = 256
      }
    }
  }

  group "wildduck" {
    count = 1

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
        image = "nodemailer/wildduck:v1.34.0"

        ports = [
          "api"
        ]
      }

      template {
        data        = file("wildduck/secrets/dbs.toml")
        destination = "secrets/config/dbs.toml"
        change_mode = "noop"
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

      # mongo client
      template {
        data = <<-EOH
        {{- with secret "pki/issue/internal" "ttl=30d" "common_name=wildduck.service.consul" -}}
        {{ .Data.private_key }}
        {{ .Data.certificate }}{{ end }}
        EOH

        destination = "secrets/certs/mongo.pem"
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
        {{- with secret "pki/issue/internal" "ttl=30d" "common_name=*.service.consul" -}}
        {{ .Data.issuing_ca }}{{ end }}
        EOH

        destination = "secrets/certs/CA.pem"
        change_mode = "restart"
        splay       = "1m"
      }

      # mongo client
      template {
        data = <<-EOH
        {{- with secret "pki/issue/internal" "ttl=30d" "common_name=wildduck.service.consul" -}}
        {{ .Data.private_key }}
        {{ .Data.certificate }}{{ end }}
        EOH

        destination = "secrets/certs/mongo.pem"
        change_mode = "restart"
        splay       = "1m"
      }
    }
  }

  group "haraka" {
    count = 2

    vault {
      policies = ["haraka"]
    }

    network {
      port "smtp" {
        to     = 587
        static = 587
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
        image = "nahsihub/haraka-wildduck:latest"

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

      # mongo client
      template {
        data = <<-EOH
        {{- with secret "pki/issue/internal" "ttl=30d" "common_name=mongo.service.consul" -}}
        {{ .Data.private_key }}
        {{ .Data.certificate }}{{ end }}
        EOH

        destination = "secrets/certs/mongo.pem"
        change_mode = "restart"
        splay       = "1m"
      }
    }
  }

  group "zone-mta" {
    count = 2

    vault {
      policies = ["zone-mta"]
    }

    network {
      port "api" {
        to = 12080
      }
      port "smtp" {
        to     = 587
        static = 587
      }
    }

    service {
      name = "zone-mta"
      port = "api"
    }

    task "zone-mta" {
      driver = "docker"

      resources {
        cpu    = 500
        memory = 256
      }

      env {
        NODE_CLUSTER_SCHED_POLICY = "none"
        ZONEMTA_CONFIG_DIR        = "/local/zone-mta/config"
      }

      config {
        image = "nahsihub/zone-mta-wildduck:latest"

        ports = [
          "api",
          "smtp"
        ]
      }

      template {
        data        = file("zone-mta/secrets/dbs.toml")
        destination = "secrets/config/dbs.toml"
        change_mode = "noop"
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

      # mongo client
      template {
        data = <<-EOH
        {{- with secret "pki/issue/internal" "ttl=30d" "common_name=zone-mta.service.consul" -}}
        {{ .Data.private_key }}
        {{ .Data.certificate }}{{ end }}
        EOH

        destination = "secrets/certs/mongo.pem"
        change_mode = "restart"
        splay       = "1m"
      }
    }
  }
}
