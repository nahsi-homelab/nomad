variables {
  versions = {
    traefik = "2.6.1"
  }
}

job "ingress" {
  datacenters = [
    "syria",
    "asia",
    "pontus"
  ]

  namespace = "infra"
  type      = "service"

  update {
    max_parallel = 1
    stagger      = "2m"
    auto_revert  = true
  }

  constraint {
    distinct_property = node.datacenter
  }

  group "traefik" {
    count = 3
    network {
      port "traefik" {
        to = 8080
      }

      port "http" {
        static       = 80
        to           = 80
        host_network = "public"
      }

      port "https" {
        static       = 443
        to           = 443
        host_network = "public"
      }

      port "smtp" {
        static       = 465
        to           = 465
        host_network = "public"
      }

      port "smtp-relay" {
        static       = 25
        to           = 25
        host_network = "public"
      }

      port "imap" {
        static       = 993
        to           = 993
        host_network = "public"
      }
    }

    service {
      name = "ingress"
      port = "traefik"

      meta {
        dashboard = "qPdAviJmz"
        alloc_id  = NOMAD_ALLOC_ID
      }

      connect {
        native = true
      }

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
        policies = ["ingress"]
      }

      config {
        image = "traefik:${var.versions.traefik}"

        ports = [
          "traefik",
          "http",
          "https",
          "smtp",
          "smtp-relay",
          "imap"
        ]

        args = [
          "--configFile=local/traefik.yml",
        ]
      }

      template {
        data        = file("traefik.yml")
        destination = "local/traefik.yml"
        splay       = "5m"

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
        {{- with secret "secret/certificate" -}}
        {{ .Data.data.ca_bundle }}{{ end }}
        EOH

        destination = "secrets/certs/nahsi.dev/cert.pem"
        change_mode = "restart"
        splay       = "5m"
      }

      template {
        data = <<-EOH
        {{- with secret "secret/certificate" -}}
        {{ .Data.data.key }}{{ end }}
        EOH

        destination = "secrets/certs/nahsi.dev/key.pem"
        change_mode = "restart"
        splay       = "5m"
      }
    }
  }
}
