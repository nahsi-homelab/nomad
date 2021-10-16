variables {
  versions = {
    traefik = "2.5.3"
    promtail = "2.3.0"
  }
}

job "traefik" {
  datacenters = ["syria", "asia"]
  namespace   = "infra"
  type        = "system"

  update {
    max_parallel = 1
    stagger      = "1m"
    auto_revert  = true
  }

  group "traefik" {
    network {
      port "traefik" {
        to = 8080
      }

      port "http" {
        static = 80
        to = 80
      }

      port "https" {
        static = 443
        to = 443
      }

      port "promtail" {
        to = 3000
      }
    }

    service {
      name = "traefik"
      port = "traefik"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.api.rule=Host(`traefik.service.consul`)",
        "traefik.http.routers.api.service=api@internal"
      ]

      check {
        type = "http"
        protocol = "http"
        path = "/ping"
        port = "traefik"
        interval = "20s"
        timeout = "2s"
      }
    }

    task "traefik" {
      driver = "docker"

      kill_timeout = "30s"

      vault {
        policies = ["internal-certs"]
      }

      config {
        image = "traefik:${var.versions.traefik}"

        extra_hosts = [
          "host.docker.internal:host-gateway"
        ]

        ports = [
          "traefik",
          "http",
          "https"
        ]

        args = [
          "--configFile=local/traefik.yml"
        ]
      }

      template {
        data        = file("traefik.yml")
        destination = "local/traefik.yml"
        change_mode = "restart"
        splay       = "1m"
      }

      template {
        data = <<EOH
tls:
  certificates:
    - certFile: "secrets/cert.pem"
      keyFile: "secrets/key.pem"

http:
  serversTransports:
    skipverify:
      insecureSkipVerify: true
EOH

        destination = "local/traefik/tls.yml"
        change_mode = "noop"
      }

      template {
        data = <<EOH
{{- with secret "pki/issue/internal" "common_name=*.service.consul" -}}
{{ .Data.certificate }}
{{ .Data.issuing_ca }}{{ end }}
EOH

        destination   = "secrets/cert.pem"
        change_mode   = "restart"
        splay         = "1m"
      }

      template {
        data = <<EOH
{{- with secret "pki/issue/internal" "common_name=*.service.consul" -}}
{{ .Data.private_key }}{{ end }}
EOH

        change_mode   = "restart"
        destination   = "secrets/key.pem"
        splay         = "1m"
      }

      resources {
        cpu = 100
        memory = 128
      }
    }

    task "promtail" {
      driver = "docker"

      lifecycle {
        hook    = "poststart"
        sidecar = true
      }

      service {
        name = "promtail"
        port = "promtail"
        tags = ["service=traefik"]
        address_mode = "host"

        check {
          type     = "http"
          path     = "/ready"
          interval = "10s"
          timeout  = "2s"
        }
      }

      resources {
        cpu = 50
        memory = 128
      }

      config {
        image = "grafana/promtail:${var.versions.promtail}"

        args = [
          "-config.file=local/promtail.yml"
        ]

        ports = [
          "promtail"
        ]
      }

      template {
        data = file("promtail.yml")
        destination = "local/promtail.yml"
      }
    }
  }
}
