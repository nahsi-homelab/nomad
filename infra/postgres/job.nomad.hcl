variables {
  versions = {
    postgres = "13.4-alpine"
    promtail = "2.3.0"
    exporter = "0.10.0"
  }
}

job "postgres" {
  datacenters = ["syria"]
  type        = "service"

  group "postgres" {
    network {
      port "postgres" {
        to = 5432
        static = 5432
      }

      port "promtail" {
        to = 3000
      }
    }

    volume "postgres" {
      type = "host"
      source = "postgres"
    }

    task "postgres" {
      driver = "docker"
      user = "70"

      vault {
        policies = ["postgres"]
      }

      service {
        name = "postgres"
        port = "postgres"
        address_mode = "host"

        check {
          name     = "Postgres TCP"
          type     = "tcp"
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
        destination = "/var/lib/postgresql/data"
      }

      config {
        image = "postgres:${var.versions.postgres}"

        ports = [
          "postgres"
        ]

        args = [
          "-c", "full_page_writes=off",
          "-c", "shared_preload_libraries=pg_stat_statements",
          "-c", "pg_stat_statements.max=10000",
          "-c", "pg_stat_statements.track=all"
        ]

        mount {
          type = "bind"
          source = "local/init"
          target = "/docker-entrypoint-initdb.d"
        }
      }

      template {
        data = <<EOF
POSTGRES_USER={{ with secret "secret/postgres" }}{{ .Data.data.username }}{{ end }}
POSTGRES_PASSWORD={{ with secret "secret/postgres" }}{{ .Data.data.password }}{{ end }}
EOF

        destination = "secrets/vars.env"
        change_mode = "noop"
        env = true
      }

      template {
        data = <<EOF
#!/bin/sh
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
  CREATE ROLE vault WITH LOGIN SUPERUSER PASSWORD 'vault'
EOSQL
EOF

        destination = "/local/init/vault.sh"
        perms = "777"
      }
    }

    task "promtail" {
      driver = "docker"

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
          "-config.file",
          "local/config.yaml",
          "-print-config-stderr",
        ]

        ports = [
          "promtail"
        ]
      }

      template {
        data = <<EOH
server:
  http_listen_port: 3000
  grpc_listen_port: 0

positions:
  filename: "local/positions.yml"

client:
  url: http://loki.service.consul:3100/loki/api/v1/push

scrape_configs:
- job_name: postgres
  static_configs:
  - targets:
      - localhost
    labels:
      app: postgres
      __path__: "/alloc/logs/postgres.stderr.0"
  pipeline_stages:
   - regex:
       expression: ^\[(?P<time>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}) \w+\] (?P<user>[\w\[\]]+)?@(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}(\(\d+\))?|\[local\])?:(?P<database>\w+|\[\w+\])? \[\d+\] [^:]*:\d+ (?P<level>\w+)
   - labels:
       level:
       database:
       user:
   - timestamp:
       source: time
       format: 2006-01-02 15:04:05.999 UTC
EOH
        destination = "local/config.yaml"
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
        policies = ["postgres-exporter"]
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
DATA_SOURCE_URI=postgres.service.consul:5432/postgres?sslmode=disable
DATA_SOURCE_USER=postgres_exporter
DATA_SOURCE_PASS={{ with secret "database/static-creds/postgres-exporter" }}{{ .Data.password }}{{ end }}
EOF

        destination = "secrets/vars.env"
        change_mode = "restart"
        env = true
      }
    }
  }
}
