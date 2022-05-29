variables {
  versions = {
    traefik  = "2.7.0"
    promtail = "2.5.0"
  }
}

job "traefik" {
  datacenters = [
    "syria",
    "asia",
  ]
  namespace = "infra"
  type      = "system"

  update {
    max_parallel = 1
    stagger      = "2m"
  }

  group "traefik" {
    network {
      port "traefik" {
        to     = 59427
        static = 59427
      }

      port "http" {
        to     = 80
        static = 80
      }

      port "https" {
        to     = 443
        static = 443
      }

      port "public" {
        to     = 444
        static = 444
      }

      port "smtp" {
        to     = 465
        static = 465
      }

      port "smtp-relay" {
        to     = 25
        static = 25
      }

      port "imap" {
        to     = 993
        static = 993
      }

      port "sftp" {
        to     = 2022
        static = 2022
      }

      port "promtail" {}
    }

    service {
      name = "traefik"
      port = "traefik"
      task = "traefik"

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
        interval = "20s"
        timeout  = "1s"
      }
    }

    service {
      name = "promtail"
      port = "promtail"

      meta {
        sidecar_to = "traefik"
        alloc_id   = NOMAD_ALLOC_ID
      }

      check {
        name     = "Promtail HTTP"
        type     = "http"
        path     = "/ready"
        port     = "promtail"
        interval = "20s"
        timeout  = "1s"
      }
    }

    task "traefik" {
      driver       = "docker"
      user         = "nobody"
      kill_timeout = "30s"

      resources {
        cpu        = 100
        memory     = 64
        memory_max = 256
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
          "public",
          "smtp",
          "smtp-relay",
          "imap",
          "sftp",
        ]

        args = [
          "--configFile=local/traefik.yml"
        ]
      }

      template {
        data        = file("traefik.yml")
        destination = "local/traefik.yml"
        change_mode = "noop"

        left_delimiter  = "[["
        right_delimiter = "]]"
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
        {{- with secret "pki/issue/internal" "common_name=*.service.consul" -}}
        {{ .Data.certificate }}
        {{ .Data.issuing_ca }}{{ end }}
        EOH

        destination = "secrets/certs/internal/cert.pem"
        change_mode = "noop"
      }

      template {
        data = <<-EOH
        {{- with secret "pki/issue/internal" "common_name=*.service.consul" -}}
        {{ .Data.private_key }}{{ end }}
        EOH

        destination = "secrets/certs/internal/key.pem"
        change_mode = "noop"
      }

      template {
        data = <<-EOH
        {{- with secret "secret/certificate" -}}
        {{ .Data.data.ca_bundle }}{{ end }}
        EOH

        destination = "secrets/certs/nahsi.dev/cert.pem"
        change_mode = "noop"
      }

      template {
        data = <<-EOH
        {{- with secret "secret/certificate" -}}
        {{ .Data.data.key }}{{ end }}
        EOH

        destination = "secrets/certs/nahsi.dev/key.pem"
        change_mode = "noop"
      }
    }

    task "promtail" {
      driver = "docker"
      user   = "nobody"

      lifecycle {
        hook    = "poststart"
        sidecar = true
      }

      vault {
        policies = ["promtail"]
      }

      resources {
        cpu        = 50
        memory     = 64
        memory_max = 128
      }

      config {
        image = "grafana/promtail:${var.versions.promtail}"

        args = [
          "-config.file=local/promtail.yml",
        ]

        ports = [
          "promtail",
        ]
      }

      template {
        data        = file("promtail.yml")
        destination = "local/promtail.yml"
      }

      template {
        data = <<-EOH
        {{- with secret "pki/issue/internal" "common_name=promtail.service.consul" -}}
        {{ .Data.issuing_ca }}{{ end }}
        EOH

        destination = "secrets/certs/CA.pem"
        change_mode = "restart"
      }

      template {
        data = <<-EOH
        {{- with secret "secret/loki/basicauth/promtail" -}}
        {{ .Data.data.password }}{{ end }}
        EOH

        destination = "secrets/auth"
      }
    }
  }
}
