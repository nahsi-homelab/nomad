variables {
  versions = {
    loki     = "2.4.1"
    promtail = "2.4.1"
  }
}

job "loki" {
  datacenters = ["syria"]
  namespace   = "observability"

  group "loki" {
    network {
      port "loki" {
        to     = 3100
        static = 3100
      }

      port "promtail" {
        to = 3000
      }
    }

    volume "loki" {
      type   = "host"
      source = "loki"
    }

    service {
      name = "promtail"
      port = "promtail"

      meta {
        sidecar_to = "loki"
      }

      check {
        type     = "http"
        path     = "/ready"
        interval = "10s"
        timeout  = "2s"
      }
    }

    service {
      name = "loki"
      port = "loki"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.loki.rule=Host(`loki.service.consul`)",
        "traefik.http.routers.loki.tls=true"
      ]

      check {
        name     = "Loki HTTP"
        type     = "http"
        path     = "/ready"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "loki" {
      driver = "docker"
      user   = "nobody"

      volume_mount {
        volume      = "loki"
        destination = "/loki"
      }

      config {
        image = "grafana/loki:${var.versions.loki}"

        ports = [
          "loki"
        ]

        args = [
          "-config.file=/local/loki.yml"
        ]
      }

      template {
        data          = file("loki.yml")
        change_mode   = "signal"
        change_signal = "SIGHUP"
        destination   = "local/loki.yml"
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
        memory = 64
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
