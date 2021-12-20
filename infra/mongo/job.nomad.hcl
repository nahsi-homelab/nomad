variables {
  versions = {
    mongo = "5.0"
  }
}

job "mongo" {
  datacenters = [
    "syria",
    "asia",
    "pontus"
  ]

  namespace = "infra"

  group "mongod" {
    count = 3
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
          "--config", "local/mongod.yml",
        ]

        volumes = [
          "local/mongodb/:/home/mongodb/",
        ]
      }

      template {
        data        = file("mongod.yml")
        destination = "local/mongod.yml"
      }

      template {
        data =<<-EOH
        {{- with secret "pki/issue/internal" "ttl=90d" "common_name=*.service.consul" -}}
        {{ .Data.issuing_ca }}{{ end }}
        EOH

        destination   = "secrets/certs/CA.pem"
        change_mode   = "restart"
        splay         = "1m"
      }

      template {
        data =<<-EOH
        {{- with secret "pki/issue/internal" "ttl=90d" "common_name=mongo.service.consul" "alt_names=mongo-primary.service.consul" -}}
        {{ .Data.private_key }}
        {{ .Data.certificate }}{{ end }}
        EOH

        destination   = "secrets/certs/primary.pem"
        change_mode   = "restart"
        splay         = "1m"
      }

      template {
        data =<<-EOH
        {{- with secret "pki/issue/internal" "ttl=90d" "common_name=mongo.service.consul" "alt_names=mongo-secondary.service.consul" -}}
        {{ .Data.private_key }}
        {{ .Data.certificate }}{{ end }}
        EOH

        destination   = "secrets/certs/secondary.pem"
        change_mode   = "restart"
        splay         = "1m"
      }

      template {
        data =<<-EOH
        {{- with secret "pki/issue/internal" "ttl=90d" "common_name=mongo.service.consul" "alt_names=mongo-arbiter.service.consul" -}}
        {{ .Data.private_key }}
        {{ .Data.certificate }}{{ end }}
        EOH

        destination   = "secrets/certs/arbiter.pem"
        change_mode   = "restart"
        splay         = "1m"
      }
    }
  }
}
