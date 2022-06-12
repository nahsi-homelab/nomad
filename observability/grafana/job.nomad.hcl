variables {
  versions = {
    grafana = "8.5.5"
  }
}

job "grafana" {
  datacenters = [
    "syria",
  ]
  namespace = "observability"

  group "grafana" {
    count = 2

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
        interval = "20s"
        timeout  = "1s"
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
          "http",
        ]
      }

      template {
        data        = file("grafana.ini")
        destination = "local/grafana.ini"
      }

      dynamic "template" {
        for_each = fileset(".", "provisioning/**")

        content {
          data        = file(template.value)
          destination = "local/${template.value}"
        }
      }

      template {
        data        = <<-EOH
        {{- with secret "secret/grafana/users/admin" -}}
        GF_SECURITY_ADMIN_USER='{{ .Data.data.username }}'
        GF_SECURITY_ADMIN_PASSWORD='{{ .Data.data.password }}'
        {{- end }}

        {{ with secret "secret/grafana/github" -}}
        GF_AUTH_GITHUB_CLIENT_ID='{{ .Data.data.client_id }}'
        GF_AUTH_GITHUB_CLIENT_SECRET='{{ .Data.data.client_secret }}'
        {{- end }}

        {{ with secret "secret/loki/basicauth/grafana" -}}
        LOKI_USERNAME='{{ .Data.data.username }}'
        LOKI_PASSWORD='{{ .Data.data.password }}'
        {{- end }}

        {{ with secret "secret/victoria-metrics/basicauth/grafana" -}}
        VM_USERNAME='{{ .Data.data.username }}'
        VM_PASSWORD='{{ .Data.data.password }}'
        {{- end }}
        EOH
        destination = "secrets/secrets.env"
        env         = true
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
