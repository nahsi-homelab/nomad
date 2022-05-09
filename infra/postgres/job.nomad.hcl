variables {
  versions = {
    patroni  = "14-2.1.3"
    exporter = "0.10.1"
  }
}

job "postgres" {
  datacenters = [
    "syria",
  ]
  namespace = "infra"

  group "patroni" {
    count = 2

    network {
      mode = "bridge"

      port "postgres" {
        to     = 5432
        static = 5432
      }

      port "patroni" {
        to     = 8008
        static = 8008
      }

      port "exporter" {
        to = 9187
      }
    }

    volume "postgres" {
      type   = "host"
      source = "postgres"
    }

    task "patroni" {
      driver = "docker"
      user   = "999"

      kill_signal  = "SIGINT"
      kill_timeout = "90s"

      vault {
        policies = ["postgres"]
      }

      resources {
        cpu    = 300
        memory = 512
      }

      volume_mount {
        volume      = "postgres"
        destination = "/data"
      }

      env {
        PATRONI_NAME                       = node.unique.name
        PATRONI_RESTAPI_CONNECT_ADDRESS    = NOMAD_ADDR_patroni
        PATRONI_POSTGRESQL_CONNECT_ADDRESS = NOMAD_ADDR_postgres
      }

      config {
        image   = "nahsihub/patroni:${var.versions.patroni}"
        init    = true
        command = "/local/patroni.yml"

        ports = [
          "postgres",
          "patroni",
        ]
      }

      template {
        data        = file("patroni.yml")
        destination = "local/patroni.yml"
      }

      template {
        data = <<-EOF
        PATRONI_SUPERUSER_USERNAME={{ with secret "secret/postgres/superuser" }}{{ .Data.data.username }}{{ end }}
        PATRONI_SUPERUSER_PASSWORD={{ with secret "secret/postgres/superuser" }}{{ .Data.data.password }}{{ end }}
        PATRONI_REPLICATION_USERNAME={{ with secret "secret/postgres/replication" }}{{ .Data.data.username }}{{ end }}
        PATRONI_REPLICATION_PASSWORD={{ with secret "secret/postgres/replication" }}{{ .Data.data.password }}{{ end }}
        EOF

        destination = "secrets/vars.env"
        env         = true
      }

      service {
        name = "patroni"
        port = "patroni"

        meta {
          alloc_id = NOMAD_ALLOC_ID
        }

        check {
          name     = "Patroni HTTP"
          type     = "http"
          path     = "/health"
          interval = "20s"
          timeout  = "1s"
        }
      }
    }

    task "postgres-exporter" {
      driver = "docker"
      user   = "nobody"

      vault {
        policies = ["postgres-exporter"]
      }

      resources {
        cpu    = 50
        memory = 64
      }

      config {
        image = "quay.io/prometheuscommunity/postgres-exporter:v${var.versions.exporter}"

        args = [
          "--log.level=info",
        ]

        ports = [
          "exporter",
        ]
      }

      template {
        data = <<-EOF
        PG_EXPORTER_AUTO_DISCOVER_DATABASES=true
        DATA_SOURCE_URI=localhost:5432/postgres?sslmode=disable
        {{ with secret "postgres/creds/postgres-exporter" }}
        DATA_SOURCE_USER='{{ .Data.username }}'
        DATA_SOURCE_PASS='{{ .Data.password }}'
        {{- end }}
        EOF

        destination = "secrets/vars.env"
        change_mode = "restart"
        env         = true
      }

      service {
        name = "postgres-exporter"
        port = "exporter"

        meta {
          alloc_id = NOMAD_ALLOC_ID
        }

        check {
          name     = "postgres-exporter"
          path     = "/"
          type     = "http"
          interval = "20s"
          timeout  = "1s"
        }
      }
    }
  }
}
