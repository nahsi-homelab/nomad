variables {
  versions = {
    mariadb  = "10.7"
    maxscale = "6.3"
    exporter = "0.13.0"
  }
}

locals {
  certs = {
    "CA"   = "issuing_ca",
    "cert" = "certificate",
    "key"  = "private_key",
  }
}

job "mariadb" {
  datacenters = ["syria"]
  namespace   = "infra"

  group "mariadb" {
    count = 2

    network {
      port "db" {
        to     = 3306
        static = 3306
      }

      port "exporter" {
        to = 9104
      }
    }

    service {
      name = "mariadb-${meta.mariadb_index}"
      port = "db"

      meta {
        alloc_id = NOMAD_ALLOC_ID
      }
    }

    service {
      name = "mariadb-exporter"
      port = "exporter"

      meta {
        alloc_id = NOMAD_ALLOC_ID
      }
    }

    volume "mariadb" {
      type   = "host"
      source = "mariadb"
    }

    task "mariadb" {
      driver = "docker"
      user   = "999"

      kill_signal  = "SIGTERM"
      kill_timeout = "90s"

      vault {
        policies = ["mariadb"]
      }

      volume_mount {
        volume      = "mariadb"
        destination = "/var/lib/mysql"
      }

      env {
        MARIADB_MYSQL_LOCALHOST_USER = true
      }

      config {
        image = "mariadb:${var.versions.mariadb}"
        init  = true

        args = [
          "--innodb_log_write_ahead_size=16384",
          "--innodb_doublewrite=0",
          "--innodb_use_native_aio=0",
          "--innodb_use_atomic_writes=0",
          "--innodb_flush_method=O_DIRECT",
          "--innodb_flush_neighbors=0",

          "--log-bin",
          "--log-basename=${node.unique.name}",
          "--server-id=${meta.mariadb_index}",
          "--binlog-format=mixed",
          "--log-slave-updates",

          "--ssl-cert=/secrets/certs/cert.pem",
          "--ssl-key=/secrets/certs/key.pem",
          "--ssl-ca=/secrets/certs/CA.pem",
        ]

        ports = [
          "db",
        ]

        mount {
          type     = "bind"
          target   = "/docker-entrypoint-initdb.d"
          source   = "secrets/init"
          readonly = true
        }
      }

      template {
        data = <<-EOF
        {{- with secret "secret/mariadb/users/superuser" -}}
        MARIADB_ROOT_PASSWORD='{{ .Data.data.password }}'
        {{- end }}
        EOF

        destination = "secrets/secrets.env"
        env         = true
        splay       = "5m"
      }

      dynamic "template" {
        for_each = fileset(".", "init/**")

        content {
          data        = file(template.value)
          destination = "secrets/${template.value}"
        }
      }

      dynamic "template" {
        for_each = local.certs
        content {
          data = <<-EOH
          {{- with secret "pki/issue/internal" "ttl=10d" "common_name=mariadb.service.consul" (env "NOMAD_ALLOC_ID" | printf "alt_names=mariadb-%s.service.consul") (env "attr.unique.network.ip-address" | printf "ip_sans=%s") -}}
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

    task "mysqld-exporter" {
      driver = "docker"
      user   = "nobody"

      vault {
        policies = ["mysqld-exporter"]
      }

      resources {
        cpu    = 50
        memory = 64
      }

      config {
        image = "prom/mysqld-exporter:v${var.versions.exporter}"
        ports = ["exporter"]
      }

      template {
        data = <<-EOF
        {{- with secret "mariadb/static-creds/exporter" }}
        DATA_SOURCE_NAME='exporter:{{ .Data.password }}@({{ env "NOMAD_ADDR_db" }})/'
        {{- end }}
        EOF

        destination = "secrets/secrets.env"
        env         = true
      }
    }
  }

  group "maxscale" {
    count = 1

    ephemeral_disk {
      sticky  = true
      migrate = true
    }

    network {
      mode = "bridge"

      port "rw" {
        to     = 3006
        static = 3006
      }

      port "ro" {
        to     = 3007
        static = 3007
      }

      port "api" {}
    }

    service {
      name = "mariadb"
      port = "rw"

      meta {
        alloc_id = NOMAD_ALLOC_ID
      }
    }

    service {
      name = "maxscale"
      port = "api"

      meta {
        alloc_id = NOMAD_ALLOC_ID
      }

      tags = [
        "traefik.enable=true",
        "traefik.consulcatalog.connect=true",
        "traefik.http.routers.maxscale.entrypoints=https",
        "traefik.http.routers.maxscale.rule=Host(`maxscale.service.consul`)",
      ]

      check {
        name     = "MaxScale HTTP"
        port     = "api"
        type     = "http"
        path     = "/"
        interval = "20s"
        timeout  = "1s"
      }

      connect {
        sidecar_service {
          proxy {
            local_service_port = 8989

            expose {
              path {
                path            = "/"
                protocol        = "http"
                local_path_port = 8989
                listener_port   = "api"
              }
            }
          }
        }
      }
    }

    task "maxscale" {
      driver = "docker"

      kill_signal  = "SIGTERM"
      kill_timeout = "10s"

      vault {
        policies = ["maxscale"]
      }

      config {
        image = "mariadb/maxscale:${var.versions.maxscale}"

        command = "maxscale"
        args = [
          "-d",
          "-U",
          "maxscale",
          "-l", "stdout"
        ]

        ports = [
          "rw",
          "ro",
        ]

        mount {
          type     = "bind"
          target   = "/etc/maxscale.cnf"
          source   = "secrets/maxscale.ini"
          readonly = true
        }
      }

      template {
        data        = file("maxscale.ini")
        destination = "secrets/maxscale.ini"
      }

      dynamic "template" {
        for_each = local.certs
        content {
          data = <<-EOH
          {{- with secret "pki/issue/internal" "ttl=10d" "common_name=mariadb.service.consul" (env "attr.unique.network.ip-address" | printf "ip_sans=%s") -}}
          {{ .Data.${template.value} }}
          {{- end -}}
          EOH

          destination = "secrets/certs/${template.key}.pem"
          change_mode = "restart"
          splay       = "10m"
        }
      }

      resources {
        cpu        = 200
        memory     = 128
        memory_max = 256
      }
    }
  }
}
