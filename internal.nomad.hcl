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

      port "metrics" {}
    }

    service {
      name = "internal"
      port = "metrics"
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
      name = "podgrab"
      port = "https"
    }

    service {
      name = "unifi"
      port = "https"
    }

    service {
      name = "jellyfin"
      port = "https"
    }

    service {
      name = "links"
      port = "https"
    }

    task "internal" {
      driver = "docker"

      vault {
        policies = ["internal-certs"]
      }

      config {
        image = "caddy:2.4.5-alpine"

        ports = [
          "http",
          "https",
          "metrics"
        ]

        volumes = [
          "local/Caddyfile:/etc/caddy/Caddyfile"
        ]
      }

      template {
        data = <<EOH
:{{ env "NOMAD_PORT_metrics" }} {
  metrics /metrics
}

home.service.consul:443 {
  tls /secrets/cert.pem /secrets/key.pem

  @websockets {
    header Connection *Upgrade*
    header Upgrade websocket
  }

  encode zstd gzip

  route /grafana* {
    reverse_proxy srv+http://grafana.service.consul
  }

  route /transmission* {
    reverse_proxy srv+http://transmission.service.consul
  }

  route /* {
    reverse_proxy srv+http://homer.service.consul
  }
}

jellyfin.service.consul:443 {
  tls /secrets/cert.pem /secrets/key.pem

  @websockets {
    header Connection *Upgrade*
    header Upgrade websocket
  }

  route /* {
   reverse_proxy srv+http://jellyfin-app.service.consul
  }
}

links.service.consul:443 {
  tls /secrets/cert.pem /secrets/key.pem

  route /* {
   reverse_proxy srv+http://linkding.service.consul
  }
}

polaris.service.consul:443 {
  tls /secrets/cert.pem /secrets/key.pem

  encode zstd gzip

  route /* {
   reverse_proxy srv+http://polaris-app.service.consul
  }
}

podgrab.service.consul:443 {
  tls /secrets/cert.pem /secrets/key.pem

  encode zstd gzip

  @websockets {
    header Connection *Upgrade*
    header Upgrade websocket
  }

  route /* {
   reverse_proxy srv+http://podgrab-app.service.consul
  }
}

unifi.service.consul:443 {
  tls /secrets/cert.pem /secrets/key.pem

  encode zstd gzip

  @websockets {
    header Connection *Upgrade*
    header Upgrade websocket
  }

  route /* {
   reverse_proxy { 
      to srv+https://unifi-controller.service.consul

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
{{- with secret "pki/issue/internal" "common_name=*.service.consul" -}}
{{ .Data.certificate }}
{{ .Data.issuing_ca }}{{ end }}
EOH

        change_mode   = "restart"
        destination   = "secrets/cert.pem"
      }

      template {
        data = <<EOH
{{- with secret "pki/issue/internal" "common_name=*.service.consul" -}}
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
