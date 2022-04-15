variables {
  versions = {
    patroni  = "14-2.1.2"
    exporter = "0.10.1"
  }
}

job "postgres" {
  datacenters = [
    "syria",
    "asia",
  ]
  namespace = "infra"

  group "patroni" {
    count = 2

    network {
      port "postgres" {
        to     = 5432
        static = 5432
      }

      port "patroni" {
        to = 8008
      }
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
        protocol = "https"
        path     = "/health"
        interval = "10s"
        timeout  = "2s"

        tls_skip_verify = true
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

        extra_hosts = [
          "host.docker.internal:host-gateway"
        ]

        ports = [
          "postgres",
          "patroni"
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
        change_mode = "noop"
        env         = true
      }

      template {
        data = <<-EOH
        {{- with secret "pki/issue/internal" "common_name=patroni.service.consul" -}}
        {{ .Data.issuing_ca }}{{ end }}
        EOH

        destination = "secrets/certs/CA.pem"
        change_mode = "restart"
        splay       = "5m"
      }

      template {
        data = <<-EOH
        {{- with secret "pki/issue/internal" "common_name=patroni.service.consul" "alt_names=localhost" "ip_sans=127.0.0.1,192.168.130.20,192.168.130.10" -}}
        {{ .Data.certificate }}{{ end }}
        EOH

        destination = "secrets/certs/cert.pem"
        change_mode = "restart"
        splay       = "5m"
      }

      template {
        data = <<-EOH
        {{- with secret "pki/issue/internal" "common_name=patroni.service.consul" "alt_names=localhost" "ip_sans=127.0.0.1,192.168.130.20,192.168.130.10" -}}
        {{ .Data.private_key }}{{ end }}
        EOH

        change_mode = "restart"
        destination = "secrets/certs/key.pem"
        splay       = "5m"
      }
    }
  }

  group "postgres-exporter" {
    network {
      port "exporter" {
        to = 9187
      }
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
        interval = "10s"
        timeout  = "2s"
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
        DATA_SOURCE_URI=master.postgres.service.consul:5432/postgres?sslmode=disable
        {{ with secret "postgres/creds/postgres-exporter" }}
        DATA_SOURCE_USER='{{ .Data.username }}'
        DATA_SOURCE_PASS='{{ .Data.password }}'
        {{- end }}
        EOF

        destination = "secrets/vars.env"
        change_mode = "restart"
        env         = true
      }
    }
  }
}
