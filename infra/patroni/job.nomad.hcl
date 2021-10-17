variables {
  versions = {
    patroni = "latest"
    promtail = "2.3.0"
    exporter = "0.10.0"
  }
}

job "patroni" {
  datacenters = ["syria", "asia"]
  namespace   = "infra"
  type        = "service"

  group "patroni" {
    count = 2

    network {
      port "postgres" {
        to = 5432
        static = 5432
      }

      port "patroni" {
        to = 8008
      }

      port "promtail" {
        to = 3000
      }
    }

    volume "postgres" {
      type = "host"
      source = "postgres"
    }

    task "patroni" {
      driver = "docker"
      user = "999"

      kill_timeout = "30s"

      vault {
        policies = ["postgres"]
      }

      service {
        name = "patroni"
        port = "patroni"
        address_mode = "host"

        check {
          name     = "Patroni HTTP"
          type     = "http"
          path     = "/health"
          interval = "10s"
          timeout  = "2s"
        }
      }

      resources {
        cpu = 300
        memory = 512
      }

      volume_mount {
        volume = "postgres"
        destination = "/data"
      }

      env {
        PATRONI_NAME = node.unique.name
        PATRONI_RESTAPI_CONNECT_ADDRESS = "${NOMAD_ADDR_patroni}"
        PATRONI_POSTGRESQL_CONNECT_ADDRESS = "${NOMAD_ADDR_postgres}"
      }

      config {
        image = "nahsihub/patroni:${var.versions.patroni}"

        command = "/local/patroni.yml"

        extra_hosts = [
          "host.docker.internal:host-gateway"
        ]

        ports = [
          "postgres",
          "patroni"
        ]
      }

      template {
        data = file("patroni.yml")
        destination = "local/patroni.yml"
      }

      template {
        data = <<EOF
PATRONI_SUPERUSER_USERNAME={{ with secret "secret/postgres/superuser" }}{{ .Data.data.username }}{{ end }}
PATRONI_SUPERUSER_PASSWORD={{ with secret "secret/postgres/superuser" }}{{ .Data.data.password }}{{ end }}
PATRONI_REPLICATION_USERNAME={{ with secret "secret/postgres/replication" }}{{ .Data.data.username }}{{ end }}
PATRONI_REPLICATION_PASSWORD={{ with secret "secret/postgres/replication" }}{{ .Data.data.password }}{{ end }}
PATRONI_vault_PASSWORD=vault
PATRONI_vault_OPTIONS='createrole,createdb'
EOF

        destination = "secrets/vars.env"
        change_mode = "noop"
        env = true
      }
    }

    task "promtail" {
      driver = "docker"
      user = "nobody"

      lifecycle {
        hook    = "poststart"
        sidecar = true
      }

      service {
        name = "promtail"
        port = "promtail"
        address_mode = "host"

        check {
          type     = "http"
          path     = "/ready"
          interval = "10s"
          timeout  = "2s"
        }
      }

      resources {
        cpu = 50
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
        data = file("promtail.yml")
        destination = "local/promtail.yml"
      }
    }
  }

  group "postgres-exporter" {
    network {
      port "exporter" {
        to = 9187
      }
    }

    task "postgres-exporter" {
      driver = "docker"
      user = "nobody"

      vault {
        policies = ["postgres"]
      }

      service {
        name = "postgres-exporter"
        port = "exporter"
        address_mode = "host"

        check {
          name     = "postgres-exporter"
          path     = "/"
          type     = "http"
          interval = "10s"
          timeout  = "2s"
        }
      }

      resources {
        memory = 64
      }

      config {
        image = "prometheuscommunity/postgres-exporter:v${var.versions.exporter}"

        ports = [
          "exporter"
        ]
      }

      template {
        data = <<EOF
PG_EXPORTER_AUTO_DISCOVER_DATABASES=true
DATA_SOURCE_URI=master.postgres.service.consul:5432/postgres?sslmode=disable
DATA_SOURCE_USER={{ with secret "secret/postgres/superuser" }}{{ .Data.data.username }}{{ end }}
DATA_SOURCE_PASS={{ with secret "secret/postgres/superuser" }}{{ .Data.data.password }}{{ end }}
EOF

        destination = "secrets/vars.env"
        change_mode = "restart"
        env = true
      }
    }
  }
}
