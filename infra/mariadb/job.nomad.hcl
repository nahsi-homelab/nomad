variables {
  versions = {
    galera   = "10.7"
    exporter = "0.13.0"
  }
}

locals {
  certs = {
    "CA"   = "issuing_ca",
    "cert" = "certificate",
    "key"  = "private_key",
  }

  options = [
    "--innodb_log_write_ahead_size=16384",
    "--innodb_doublewrite=0",
    "--innodb_use_native_aio=0",
    "--innodb_use_atomic_writes=0",
    "--innodb_flush_method=O_DIRECT",
    "--innodb_flush_neighbors=0",
  ]
}

job "mariadb" {
  datacenters = ["syria"]
  namespace   = "infra"

  group "galera" {
    count = 2

    network {
      port "db" {
        to     = 3306
        static = 3306
      }

      port "replication" {
        to     = 4567
        static = 4567
      }

      port "ist" {
        # Incremental State Transfer
        to     = 4568
        static = 4568
      }

      port "sst" {
        # State Snapshot Transfer
        to     = 4444
        static = 4444
      }
    }

    service {
      name = "mariadb"
      port = "db"

      meta {
        alloc_id = NOMAD_ALLOC_ID
      }
    }

    service {
      name = "mariadb-${NOMAD_ALLOC_INDEX}"
      port = "db"

      meta {
        alloc_id = NOMAD_ALLOC_ID
      }
    }

    volume "mariadb" {
      type   = "host"
      source = "mariadb"
    }

    task "galera" {
      driver = "docker"

      kill_signal  = "SIGTERM"
      kill_timeout = "90s"

      vault {
        policies = ["mariadb"]
      }

      volume_mount {
        volume      = "mariadb"
        destination = "/bitnami/mariadb"
      }

      env {
        MARIADB_GALERA_CLUSTER_NAME    = "galera"
        MARIADB_GALERA_NODE_ADDRESS    = NOMAD_ADDR_replication
        MARIADB_GALERA_CLUSTER_ADDRESS = "gcomm://mariadb-0.service.consul:4567,mariadb-1.service.consul:4567"

        MARIADB_ENABLE_SSL    = "yes"
        MARIADB_TLS_CERT_FILE = "/secrets/certs/cert.pem"
        MARIADB_TLS_KEY_FILE  = "/secrets/certs/key.pem"
        MARIADB_TLS_CA_FILE   = "/secrets/certs/CA.pem"

        MARIADB_EXTRA_FLAGS = join(" ", local.options)
      }

      config {
        image        = "bitnami/mariadb-galera:${var.versions.galera}"
        network_mode = "host"

        ports = [
          "db",
          "replication",
          "ist",
          "sst",
        ]
      }

      template {
        data = <<-EOF
        {{- with secret "secret/mariadb/users/superuser" -}}
        MARIADB_ROOT_USER='{{ .Data.data.username }}'
        MARIADB_ROOT_PASSWORD='{{ .Data.data.password }}'
        {{- end }}

        {{ with secret "secret/mariadb/users/replication" -}}
        MARIADB_REPLICATION_USER='{{ .Data.data.username }}'
        MARIADB_REPLICATION_PASSWORD='{{ .Data.data.password }}'
        {{- end }}

        {{ with secret "secret/mariadb/users/backup" -}}
        MARIADB_GALERA_MARIABACKUP_USER='{{ .Data.data.username }}'
        MARIADB_GALERA_MARIABACKUP_PASSWORD='{{ .Data.data.password }}'
        {{- end }}
        EOF

        destination = "local/secrets.env"
        env         = true
      }

      dynamic "template" {
        for_each = local.certs
        content {
          data = <<-EOH
          {{- with secret "pki/issue/internal" "ttl=10d" "common_name=mariadb.service.consul" (env "NOMAD_ALLOC_INDEX" | printf "alt_names=mariadb-%s.service.consul") (env "attr.unique.network.ip-address" | printf "ip_sans=%s") -}}
          {{ .Data.${template.value} }}
          {{- end -}}
          EOH

          destination = "secrets/certs/${template.key}.pem"
          change_mode = "restart"
          splay       = "10m"
        }
      }

      resources {
        cpu        = 300
        memory     = 256
        memory_max = 512
      }
    }
  }
}
