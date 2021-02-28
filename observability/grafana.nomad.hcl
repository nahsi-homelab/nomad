job "grafana" {
  datacenters = ["syria"]
  type        = "service"

  group "grafana" {
    count = 1

    network {
      port "http" {
        to = 3000
      }
    }

    restart {
      attempts = 3
      delay    = "20s"
      mode     = "delay"
    }

    task "grafana" {
      driver = "podman"

      vault {
        policies = ["grafana"]
      }

      config {
        image = "docker://grafana/grafana:7.4.3"

        dns = ["10.88.0.1"]

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
# HTTP options
[server]
# The public facing domain name used to access grafana from a browser
domain = home.service.consul

# Redirect to correct domain if host header does not match domain
# Prevents DNS rebinding attacks
enforce_domain = false

# # The full public facing url you use in browser, used for redirects and emails
# If you use reverse proxy and sub path specify full url (with sub path)
root_url = https://home.service.consul/grafana
serve_from_sub_path = true

# Users management and registration
[users]
allow_sign_up = false
allow_org_create = false
auto_assign_org_role = Viewer
default_theme = dark

[security]
admin_password = $__file{/secrets/admin_password}

# Authentication
[auth]
disable_login_form = false
oauth_auto_login = false
disable_signout_menu = false

[auth.github]
enabled = true
allow_sign_up = true
client_id = $__file{/secrets/github/client_id}
client_secret = $__file{/secrets/github/secret_id}
scopes = user:email,read:org
auth_url = https://github.com/login/oauth/authorize
token_url = https://github.com/login/oauth/access_token
api_url = https://api.github.com/user
allowed_organizations = nahsi-homelab

# Logging
[log]
mode = console
level = info
EOH

        destination = "local/grafana.ini"
      }

      template {
        data = <<EOH
{{ with secret "secret/grafana/github" }}{{ .Data.data.client_id }}{{ end }}
EOH

        destination = "secrets/github/client_id"
      }

      template {
        data = <<EOH
{{ with secret "secret/grafana/github" }}{{ .Data.data.secret_id }}{{ end }}
EOH

        destination = "secrets/github/secret_id"
      }

      template {
        data = <<EOH
{{ with secret "secret/grafana/users/admin" }}{{ .Data.data.password }}{{ end }}
EOH

        destination = "secrets/admin_password"
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
    url: https://home.service.consul/prometheus
EOH

        destination = "local/provisioning/datasources/datasources.yml"
      }

      service {
        name = "grafana"
        tags = ["monitoring"]

        port = "http"

        check {
          name = "Grafana HTTP"
          type     = "http"
          path     = "/api/health"
          interval = "5s"
          timeout  = "2s"

          check_restart {
            limit           = 2
            grace           = "60s"
            ignore_warnings = false
          }
        }
      }

      resources {
        cpu    = 100
        memory = 100
      }
    }
  }
}
