job "internal" {

  datacenters = ["syria"]
  type        = "service"

  group "internal" {
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

    task "internal" {
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
          "local/Caddyfile:/etc/caddy/Caddyfile"
        ]
      }

      template {
        data = <<EOH
home.service.consul:443 {
  tls /secrets/cert.pem /secrets/key.pem

  @websockets {
    header Connection *Upgrade*
    header Upgrade websocket
  }

  route /grafana* {
    {{- range service "grafana" }}
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

jellyfin.service.consul:443 {
  tls /secrets/cert.pem /secrets/key.pem

  @websockets {
    header Connection *Upgrade*
    header Upgrade websocket
  }

  route /* {
   reverse_proxy {
      {{- range service "jellyfin" }}
      to {{ .Address }}:{{ .Port }}
      {{- end }}
    }
  }
}

polaris.service.consul:443 {
  tls /secrets/cert.pem /secrets/key.pem

  route /* {
   reverse_proxy {
      {{- range service "polaris-app" }}
      to {{ .Address }}:{{ .Port }}
      {{- end }}
    }
  }
}

unifi.service.consul:443 {
  tls /secrets/cert.pem /secrets/key.pem

  @websockets {
    header Connection *Upgrade*
    header Upgrade websocket
  }

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
{{- with secret "pki/issue/consul" "common_name=home.service.consul" "alt_names=polaris.service.consul,unifi.service.consul" -}}
{{ .Data.certificate }}
{{ .Data.issuing_ca }}{{ end }}
EOH

        change_mode   = "restart"
        destination   = "secrets/cert.pem"
      }

      template {
        data = <<EOH
{{- with secret "pki/issue/consul" "common_name=home.service.consul" "alt_names=polaris.service.consul,unifi.service.consul" -}}
{{ .Data.private_key }}{{ end }}
EOH

        change_mode   = "restart"
        destination   = "secrets/key.pem"
      }

      resources {
        memory = 128
      }
    }
  }
}
