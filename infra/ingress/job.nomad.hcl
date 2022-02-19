variables {
  versions = {
    traefik  = "2.6.1"
    promtail = "2.4.2"
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
    stagger      = "1m"
  }

  constraint {
    distinct_property = "${node.datacenter}"
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

      port "promtail" {
        to = 3000
      }
    }

    task "traefik" {
      driver       = "docker"
      kill_timeout = "30s"

      vault {
        policies = ["public-cert"]
      }

      resources {
        cpu        = 50
        memory     = 32
        memory_max = 64
      }

      service {
        name = "ingress"
        port = "traefik"

        meta {
          alloc_id = NOMAD_ALLOC_ID
        }

        check {
          type     = "http"
          protocol = "http"
          path     = "/ping"
          port     = "traefik"
          interval = "20s"
          timeout  = "2s"
        }
      }

      config {
        image = "traefik:${var.versions.traefik}"

        extra_hosts = [
          "host.docker.internal:host-gateway"
        ]

        ports = [
          "traefik",
          "http",
          "https",
          "smtp",
          "smtp-relay",
          "imap"
        ]

        args = [
          "--configFile=local/traefik.yml"
        ]
      }

      template {
        data        = file("traefik.yml")
        destination = "local/traefik.yml"
      }

      template {
        data        = file("file.yml")
        destination = "local/traefik/file.yml"
      }

      template {
        data = <<-EOH
        {{- with secret "secret/certificate" -}}
        {{ .Data.data.ca_bundle }}{{ end }}
        EOH

        destination = "secrets/cert.pem"
        change_mode = "restart"
        splay       = "1m"
      }

      template {
        data = <<-EOH
        {{- with secret "secret/certificate" -}}
        {{ .Data.data.key }}{{ end }}
        EOH

        destination = "secrets/key.pem"
        change_mode = "restart"
        splay       = "1m"
      }
    }

    task "promtail" {
      driver = "docker"

      lifecycle {
        hook    = "poststart"
        sidecar = true
      }

      resources {
        cpu    = 50
        memory = 32
      }

      service {
        name = "promtail"
        port = "promtail"

        meta {
          sidecar_to = "traefik"
        }

        check {
          type     = "http"
          path     = "/ready"
          interval = "20s"
          timeout  = "2s"
        }
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
        data        = file("promtail.yml")
        destination = "local/promtail.yml"
      }
    }
  }
}
