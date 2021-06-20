# vim: set ft=hcl sw=2 ts=2 :
job "caddy" {

  datacenters = ["syria"]

  type        = "service"

  group "caddy" {
    network {
      port "http" {
        static = 80
        to = 80
      }

      port "https" {
        static = 443
        to = 443
      }
    }

    service {
      name = "home"
      port = "https"
    }

    task "caddy" {
      driver = "docker"

      vault {
        policies = ["internal-certs"]
      }

      config {
        image = "caddy:2.3.0-alpine"

        ports = [
          "http",
          "https"
        ]

        volumes = [
          "local/Caddyfile:/etc/caddy/Caddyfile",
          "/mnt/apps/caddy/:/data"
        ]
      }

      template {
        data = <<EOH
home.service.{{ env "NOMAD_DC" }}.consul:443 {
  tls /secrets/cert.pem /secrets/key.pem

  route /grafana* {
    {{- range service "grafana" }}
    reverse_proxy {{ .Address }}:{{ .Port }}
    {{- end }}
  }

  route /prometheus* {
    {{- range service "prometheus" }}
    reverse_proxy {{ .Address }}:{{ .Port }}
    {{- end }}
  }

  handle_path /victoria-metrics* {
    {{- range service "victoria-metrics" }}
    reverse_proxy {{ .Address }}:{{ .Port }}
    {{- end }}
  }

  route /jellyfin* {
    {{- range service "jellyfin" }}
    reverse_proxy {{ .Address }}:{{ .Port }}
    {{- end }}
  }

  handle_path /audioserve* {
    {{- range service "audioserve" }}
    reverse_proxy {{ .Address }}:{{ .Port }}
    {{- end }}
  }

  route /* {
   reverse_proxy {
      {{- range service "homer" }}
      to {{ .Address }}:{{ .Port }}
      {{- end }}
    }
  }
}
EOH

        destination   = "local/Caddyfile"
        change_mode   = "signal"
        change_signal = "SIGINT"
      }

      template {
        data = <<EOH
{{ with secret "pki/internal/cert/ca" }}
{{- .Data.certificate }}{{ end }}
EOH

        destination = "secrets/ca.crt"
      }

      template {
        data = <<EOH
{{- with node }}
{{- $CN := printf "common_name=home.service.%s.consul" .Node.Datacenter }}
{{- with secret "pki/internal/issue/consul" $CN "alt_names=home.service.consul" }}
{{- .Data.certificate }}{{ end }}{{ end }}
EOH

        change_mode   = "restart"
        destination   = "secrets/cert.pem"
      }

      template {
        data = <<EOH
{{- with node }}
{{- $CN := printf "common_name=home.service.%s.consul" .Node.Datacenter }}
{{- with secret "pki/internal/issue/consul" $CN "alt_names=home.service.consul" }}
{{- .Data.private_key }}{{ end }}{{ end }}
EOH

        change_mode   = "restart"
        destination   = "secrets/key.pem"
      }

      resources {
        cpu = 100
        memory = 300
      }
    }
  }
}
