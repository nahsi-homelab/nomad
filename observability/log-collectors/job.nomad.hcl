variables {
  versions = {
    vector   = "0.20.0"
    promtail = "2.4.2"
  }
}

job "log-collectors" {
  datacenters = [
    "syria",
    "asia",
    "pontus",
  ]
  namespace = "observability"
  type      = "system"

  update {
    max_parallel = 1
    stagger      = "1m"
    auto_revert  = true
  }

  group "log-collectors" {
    ephemeral_disk {
      size = 500
    }

    network {
      mode = "bridge"

      port "vector" {}
      port "promtail" {}
      port "loki" {}
    }

    service {
      name = "promtail"
      port = "promtail"

      meta {
        alloc_id   = NOMAD_ALLOC_ID
        sidecar_to = "nomad"
      }

      check {
        type     = "http"
        path     = "/ready"
        interval = "10s"
        timeout  = "1s"
      }
    }

    service {
      name = "vector"
      port = "vector"

      meta {
        alloc_id = NOMAD_ALLOC_ID
      }

      check {
        type     = "http"
        path     = "/health"
        interval = "10s"
        timeout  = "1s"
      }
    }

    volume "docker-socket" {
      type      = "host"
      source    = "docker-socket"
      read_only = true
    }

    task "promtail" {
      driver = "docker"
      user   = "nobody"

      vault {
        policies = ["promtail"]
      }

      resources {
        cpu    = 100
        memory = 64
      }

      config {
        image = "grafana/promtail:${var.versions.promtail}"

        args = [
          "-config.file=local/promtail.yml"
        ]

        ports = [
          "promtail",
        ]
      }

      template {
        data            = file("promtail.yml")
        destination     = "local/promtail.yml"
        left_delimiter  = "[["
        right_delimiter = "]]"
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
        {{- with secret "secret/promtail/loki" -}}
        {{ .Data.data.username }}:{{ .Data.data.password }}{{ end }}
        EOH

        destination = "secrets/auth"
      }
    }

    task "vector" {
      driver = "docker"

      resources {
        cpu    = 50
        memory = 64
      }

      lifecycle {
        hook    = "poststart"
        sidecar = true
      }

      volume_mount {
        volume      = "docker-socket"
        destination = "/var/run/docker.sock"
        read_only   = true
      }

      env {
        VECTOR_CONFIG          = "local/vector.toml"
        VECTOR_REQUIRE_HEALTHY = "true"
      }

      config {
        image = "timberio/vector:${var.versions.vector}-alpine"

        ports = [
          "vector"
        ]
      }

      template {
        data            = file("vector.toml")
        destination     = "local/vector.toml"
        change_mode     = "signal"
        change_signal   = "SIGHUP"
        left_delimiter  = "[["
        right_delimiter = "]]"
      }
    }
  }
}
