# vim: set ft=hcl sw=2 ts=2 :
job "dashboard" {

  datacenters = ["syria"]
  type        = "service"

  group "dashboard" {
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

    service {
      name = "polaris"
      port = "https"
    }

    service {
      name = "unifi"
      port = "https"
    }

    task "dashboard" {
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
  tls /secrets/home-cert.pem /secrets/home-key.pem

  @websockets {
    header Connection *Upgrade*
    header Upgrade websocket
  }

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

  route /transmission* {
    {{- range service "transmission" }}
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

polaris.service.{{ env "NOMAD_DC" }}.consul:443 {
  tls /secrets/polaris-cert.pem /secrets/polaris-key.pem

  route /* {
   reverse_proxy {
      {{- range service "polaris-app" }}
      to {{ .Address }}:{{ .Port }}
      {{- end }}
    }
  }
}

unifi.service.{{ env "NOMAD_DC" }}.consul:443 {
  tls /secrets/unifi-cert.pem /secrets/unifi-key.pem

  route /* {
   reverse_proxy {
      {{- range service "unifi-controller" }}
      to https://{{ .Address }}:{{ .Port }}
      {{- end }}

      transport http {
        tls
        tls_insecure_skip_verify
      }
    }
  }
}
EOH

        destination   = "local/Caddyfile"
        change_mode   = "restart"
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
        destination   = "secrets/home-cert.pem"
      }

      template {
        data = <<EOH
{{- with node }}
{{- $CN := printf "common_name=home.service.%s.consul" .Node.Datacenter }}
{{- with secret "pki/internal/issue/consul" $CN "alt_names=home.service.consul" }}
{{- .Data.private_key }}{{ end }}{{ end }}
EOH

        change_mode   = "restart"
        destination   = "secrets/home-key.pem"
      }

      template {
        data = <<EOH
{{- with node }}
{{- $CN := printf "common_name=polaris.service.%s.consul" .Node.Datacenter }}
{{- with secret "pki/internal/issue/consul" $CN "alt_names=polaris.service.consul" }}
{{- .Data.certificate }}{{ end }}{{ end }}
EOH

        change_mode   = "restart"
        destination   = "secrets/polaris-cert.pem"
      }

      template {
        data = <<EOH
{{- with node }}
{{- $CN := printf "common_name=polaris.service.%s.consul" .Node.Datacenter }}
{{- with secret "pki/internal/issue/consul" $CN "alt_names=polaris.service.consul" }}
{{- .Data.private_key }}{{ end }}{{ end }}
EOH

        change_mode   = "restart"
        destination   = "secrets/polaris-key.pem"
      }

      template {
        data = <<EOH
{{- with node }}
{{- $CN := printf "common_name=unifi.service.%s.consul" .Node.Datacenter }}
{{- with secret "pki/internal/issue/consul" $CN "alt_names=unifi.service.consul" }}
{{- .Data.certificate }}{{ end }}{{ end }}
EOH

        change_mode   = "restart"
        destination   = "secrets/unifi-cert.pem"
      }

      template {
        data = <<EOH
{{- with node }}
{{- $CN := printf "common_name=unifi.service.%s.consul" .Node.Datacenter }}
{{- with secret "pki/internal/issue/consul" $CN "alt_names=unifi.service.consul" }}
{{- .Data.private_key }}{{ end }}{{ end }}
EOH

        change_mode   = "restart"
        destination   = "secrets/unifi-key.pem"
      }

      resources {
        memory = 128
      }
    }
  }
}
