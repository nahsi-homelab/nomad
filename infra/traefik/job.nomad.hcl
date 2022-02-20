variables {
  versions = {
    traefik = "2.6.1"
  }
}

job "traefik" {
  datacenters = [
    "syria",
    "asia",
    "pontus"
  ]
  namespace = "infra"
  type      = "system"

  update {
    max_parallel = 1
    stagger      = "2m"
    auto_revert  = true
  }

  group "traefik" {
    network {
      port "traefik" {
        to = 8080
      }

      port "http" {
        static = 80
        to     = 80
      }

      port "https" {
        static = 443
        to     = 443
      }
    }

    service {
      name = "traefik"
      port = "traefik"

      meta {
        dashboard = "qPdAviJmz"
        alloc_id  = NOMAD_ALLOC_ID
      }

      connect {
        native = true
      }

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.api.entrypoints=https",
        "traefik.http.routers.api.rule=Host(`traefik.service.consul`)",
        "traefik.http.routers.api.service=api@internal",
      ]

      check {
        name     = "Traefik HTTP"
        type     = "http"
        path     = "/ping"
        port     = "traefik"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "traefik" {
      driver       = "docker"
      user         = "nobody"
      kill_timeout = "30s"

      resources {
        cpu        = 100
        memory     = 64
        memory_max = 128
      }

      vault {
        policies = ["traefik"]
      }

      config {
        image = "traefik:${var.versions.traefik}"

        ports = [
          "traefik",
          "http",
          "https",
        ]

        args = [
          "--configFile=local/traefik.yml"
        ]
      }

      template {
        data        = file("traefik.yml")
        destination = "local/traefik.yml"
      }

      dynamic "template" {
        for_each = fileset(".", "configs/*.yml")

        content {
          data        = file(template.value)
          destination = "local/${template.value}"
          change_mode = "noop"

          left_delimiter  = "[["
          right_delimiter = "]]"
        }
      }

      template {
        data = <<-EOH
        {{- with secret "pki/issue/internal" "common_name=traefik.service.consul" -}}
        {{ .Data.certificate }}
        {{ .Data.issuing_ca }}{{ end }}
        EOH

        destination = "secrets/cert.pem"
        change_mode = "restart"
        splay       = "5m"
      }

      template {
        data = <<-EOH
        {{- with secret "pki/issue/internal" "common_name=traefik.service.consul" -}}
        {{ .Data.private_key }}{{ end }}
        EOH

        change_mode = "restart"
        destination = "secrets/key.pem"
        splay       = "5m"
      }
    }
  }
}
