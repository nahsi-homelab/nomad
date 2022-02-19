variables {
  versions = {
    grafana = "8.4.1"
  }
}

job "grafana" {
  datacenters = [
    "syria",
    "asia"
  ]
  namespace = "observability"

  group "grafana" {
    count = 2
    constraint {
      distinct_property = node.datacenter
    }

    network {
      mode = "bridge"
      port "http" {
        to = 3000
      }
    }

    service {
      name = "grafana"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.grafana.entrypoints=https",
        "traefik.http.routers.grafana.rule=Host(`grafana.service.consul`)",
      ]

      meta {
        dashboard = "isFoa0z7k"
        alloc_id  = NOMAD_ALLOC_ID
      }

      check {
        name     = "Grafana HTTP"
        type     = "http"
        path     = "/api/health"
        interval = "10s"
        timeout  = "2s"
      }
    }

    service {
      name = "grafana-connect"
      port = 3000

      meta {
        dashboard = "isFoa0z7k"
        alloc_id  = NOMAD_ALLOC_ID
      }

      connect {
        sidecar_service {
          proxy {
            local_service_port = 3000
            upstreams {
              destination_name = "victoria-metrics"
              local_bind_port  = 8428
            }
          }
        }
      }

      check {
        expose   = true
        name     = "Grafana HTTP"
        type     = "http"
        path     = "/api/health"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "grafana" {
      driver = "docker"
      user   = "nobody"

      vault {
        policies = ["grafana"]
      }

      resources {
        cpu    = 100
        memory = 128
      }

      env {
        GF_PATHS_CONFIG       = "/local/grafana.ini"
        GF_PATHS_PROVISIONING = "/local/provisioning"
      }

      config {
        image = "grafana/grafana:${var.versions.grafana}"

        ports = [
          "http"
        ]
      }

      template {
        data        = file("grafana.ini")
        destination = "local/grafana.ini"
      }

      template {
        data        = file("provisioning/datasources.yml")
        destination = "local/provisioning/datasources/datasources.yml"
      }

      template {
        data        = <<-EOH
        {{ with secret "secret/grafana/github" }}{{ .Data.data.client_id }}{{ end }}
        EOH
        destination = "secrets/github/client_id"
      }

      template {
        data        = <<-EOH
        {{ with secret "secret/grafana/github" }}{{ .Data.data.secret_id }}{{ end }}
        EOH
        destination = "secrets/github/secret_id"
      }

      template {
        data        = <<-EOH
        {{ with secret "secret/grafana/users/admin" }}{{ .Data.data.password }}{{ end }}
        EOH
        destination = "secrets/admin_password"
      }

      template {
        data        = <<-EOH
        {{ with secret "postgres/creds/grafana" }}
        GF_DATABASE_USER='{{ .Data.username }}'
        GF_DATABASE_PASSWORD='{{ .Data.password }}'
        {{- end }}
        EOH
        destination = "secrets/db.env"
        env         = true
        splay       = "3m"
      }
    }
  }
}
