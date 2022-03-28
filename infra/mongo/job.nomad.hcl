variables {
  versions = {
    mongo    = "5.0"
    exporter = "0.30"
  }
}

locals {
  voters = [
    "primary",
    "secondary",
  ]
}

job "mongo" {
  datacenters = [
    "syria",
    "asia",
    "pontus",
  ]
  namespace = "infra"

  group "mongo-voters" {
    count = 2

    network {
      port "db" {
        to     = 27017
        static = 27017
      }
    }

    service {
      name = "mongo-${meta.mongo_node_id}"
      port = "db"
    }

    service {
      name = "mongo"
      port = "db"
    }

    volume "mongo" {
      type   = "host"
      source = "mongo"
    }

    task "mongod" {
      driver = "docker"
      user   = "999"

      resources {
        cpu    = 500
        memory = 512
      }

      vault {
        policies = ["mongo"]
      }

      volume_mount {
        volume      = "mongo"
        destination = "/data/db"
      }

      config {
        image    = "mongo:${var.versions.mongo}"
        hostname = "mongo-${meta.mongo_node_id}.service.consul"

        ports = ["db"]

        args = [
          "--bind_ip=0.0.0.0",
          "--quiet",
          "--replSet=main",
          "--clusterAuthMode=x509",
          "--tlsMode=preferTLS",
          "--tlsCAFile=/secrets/certs/CA.pem",
          "--tlsClusterFile=/secrets/certs/${meta.mongo_node_id}.pem",
          "--tlsCertificateKeyFile=/secrets/certs/${meta.mongo_node_id}.pem",
        ]
      }

      template {
        data = <<-EOH
        {{- with secret "pki/issue/internal" "ttl=90d" "common_name=*.service.consul" -}}
        {{ .Data.issuing_ca }}{{ end }}
        EOH

        destination = "secrets/certs/CA.pem"
        change_mode = "restart"
        splay       = "1m"
      }

      dynamic "template" {
        for_each = local.voters
        content {
          data = <<-EOH
          {{- with secret "pki/issue/internal" "ttl=90d" "common_name=mongo.service.consul" "alt_names=mongo-${template.value}.service.consul" -}}
          {{ .Data.private_key }}
          {{ .Data.certificate }}{{ end }}
          EOH

          destination = "secrets/certs/${template.value}.pem"
          change_mode = "restart"
          splay       = "1m"
        }
      }
    }
  }

  group "mongo-arbiter" {
    count = 1

    constraint {
      attribute = node.datacenter
      value     = "pontus"
    }

    network {
      port "db" {
        to     = 27017
        static = 27017
      }
    }

    service {
      name = "mongo-arbiter"
      port = "db"
    }

    service {
      name = "mongo"
      port = "db"
    }

    task "mongod" {
      driver = "docker"
      user   = "999"

      resources {
        cpu    = 300
        memory = 256
      }

      vault {
        policies = ["mongo"]
      }

      config {
        image    = "mongo:${var.versions.mongo}"
        hostname = "mongo-arbiter.service.consul"

        ports = ["db"]

        args = [
          "--bind_ip=0.0.0.0",
          "--quiet",
          "--replSet=main",
          "--clusterAuthMode=x509",
          "--tlsMode=preferTLS",
          "--tlsCAFile=/secrets/certs/CA.pem",
          "--tlsClusterFile=/secrets/certs/arbiter.pem",
          "--tlsCertificateKeyFile=/secrets/certs/arbiter.pem",
        ]
      }

      template {
        data = <<-EOH
        {{- with secret "pki/issue/internal" "ttl=90d" "common_name=*.service.consul" -}}
        {{ .Data.issuing_ca }}{{ end }}
        EOH

        destination = "secrets/certs/CA.pem"
        change_mode = "restart"
        splay       = "1m"
      }

      template {
        data = <<-EOH
        {{- with secret "pki/issue/internal" "ttl=90d" "common_name=mongo.service.consul" "alt_names=mongo-arbiter.service.consul" -}}
        {{ .Data.private_key }}
        {{ .Data.certificate }}{{ end }}
        EOH

        destination = "secrets/certs/arbiter.pem"
        change_mode = "restart"
        splay       = "1m"
      }
    }
  }

  group "mongo-exporter" {
    network {
      port "exporter" {
        to = 9216
      }
    }

    service {
      name = "mongo-exporter"
      port = "exporter"

      meta {
        alloc_id = NOMAD_ALLOC_ID
      }
    }

    task "mongo-exporter" {
      driver = "docker"
      user   = "65535"

      resources {
        cpu    = 50
        memory = 64
      }

      vault {
        policies = ["mongo-exporter"]
      }

      config {
        image = "percona/mongodb_exporter:${var.versions.exporter}"

        ports = ["exporter"]

        args = [
          "--log.level=warn",
          "--mongodb.direct-connect=false",
          "--no-collector.diagnosticdata=false",
          "--compatible-mode=true"
        ]
      }

      template {
        data = <<-EOH
        MONGODB_URI=mongodb://{{- with secret "mongo/creds/exporter" -}}{{ .Data.username }}:{{ .Data.password }}{{ end -}}@mongo-primary.service.consul:27017,mongo-secondary.service.consul:27017,mongo-arbiter.service.consul:27017/admin?tls=true&tlsCertificateKeyFile=/secrets/certs/key.pem&tlsCAFile=/secrets/certs/CA.pem
        EOH

        destination = "secrets/env"
        change_mode = "restart"
        env         = true
      }

      template {
        data = <<-EOH
        {{- with secret "pki/issue/internal" "common_name=*.service.consul" -}}
        {{ .Data.issuing_ca }}{{ end }}
        EOH

        destination = "secrets/certs/CA.pem"
        change_mode = "restart"
        splay       = "1m"
      }

      template {
        data = <<-EOH
        {{- with secret "pki/issue/internal" "ttl=90d" "common_name=mongo-exporter.service.consul" -}}
        {{ .Data.private_key }}
        {{ .Data.certificate }}{{ end }}
        EOH

        destination = "secrets/certs/key.pem"
        change_mode = "restart"
        splay       = "1m"
      }
    }
  }
}
