variables {
  versions = {
    mariadb  = "10.7"
    exporter = "0.13.0"
  }
}

job "mariadb" {
  datacenters = ["syria"]
  namespace   = "infra"

  group "mariadb" {
    network {
      port "db" {
        to     = 3306
        static = 3306
      }
    }

    service {
      name = "mariadb"
      port = "db"

      meta {
        alloc_id = NOMAD_ALLOC_ID
      }
    }

    volume "mariadb" {
      type            = "csi"
      source          = "mariadb"
      attachment_mode = "file-system"
      access_mode     = "single-node-writer"
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

      resources {
        cpu    = 300
        memory = 256
      }

      config {
        image = "mariadb:${var.versions.mariadb}"
        init  = true
        ports = ["db"]
      }

      template {
        data = <<-EOF
        MARIADB_ROOT_PASSWORD={{ with secret "secret/mariadb/root" }}{{ .Data.data.password }}{{ end }}
        EOF

        destination = "secrets/vars.env"
        change_mode = "noop"
        env         = true
      }
    }
  }

  group "exporter" {
    network {
      port "http" {
        to = 9104
      }
    }

    service {
      name = "mariadb-exporter"
      port = "http"

      meta {
        alloc_id = NOMAD_ALLOC_ID
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
        ports = ["http"]
      }

      template {
        data = <<-EOF
        {{- with secret "mariadb/creds/exporter" }}
        DATA_SOURCE_NAME='{{ .Data.username }}:{{ .Data.password }}@(mariadb.service.consul:3306)/'
        {{- end }}
        EOF

        destination = "secrets/vars.env"
        env         = true
      }
    }
  }
}
