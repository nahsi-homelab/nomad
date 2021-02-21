job "grafana" {
  datacenters = ["syria"]
  type        = "service"

  group "grafana" {
    network {
      port "http" {
        to = 3000
      }
    }

    service {
      name = "grafana"
      port = "http"

      check {
        type     = "http"
        path     = "/health"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "grafana" {
      driver = "podman"

      config {
        image = "docker://grafana/grafana:7.4.2"

        ports = [
          "http"
        ]

        volumes = [
          "local/grafana.ini:/etc/grafana/grafana.ini",
          "local/provisioning:/etc/grafana/provisioning",
          "/mnt/apps/grafana/:/var/lib/grafana"
        ]
      }

      template {
        data = <<EOH
app_mode = development

# HTTP options
[server]
# The public facing domain name used to access grafana from a browser
domain =

# Redirect to correct domain if host header does not match domain
# Prevents DNS rebinding attacks
enforce_domain = false

# # The full public facing url you use in browser, used for redirects and emails
# If you use reverse proxy and sub path specify full url (with sub path)
root_url = http://grafana.service.consul

# Security
[security]
admin_user = admin
admin_password = foobar

# Users management and registration
[users]
allow_sign_up = False
allow_org_create = False
auto_assign_org_role = Viewer
default_theme = dark

# Authentication
[auth]
disable_login_form = False
oauth_auto_login = False
disable_signout_menu = False
signout_redirect_url =

# Dashboards
[dashboards]
versions_to_keep = 10

# Logging
[log]
mode = console
level = info
EOH

        destination   = "local/grafana.ini"
      }

      template {
        data = <<EOH
---
apiVersion: 1
deleteDatasources: []
datasources:
  - basicAuth: false
    isDefault: true
    jsonData:
      timeInterval: 15s
    name: Prometheus
    type: prometheus
    url: >-
      {{ with service "prometheus" -}}
      {{ with index . 0 -}}
      http://{{ .Address }}:{{ .Port }}{{ end }}{{ end }}
EOH

        destination = "local/provisioning/datasources/datasources.yml"
      }

      resources {
        cpu    = 100
        memory = 150
      }
    }
  }
}
