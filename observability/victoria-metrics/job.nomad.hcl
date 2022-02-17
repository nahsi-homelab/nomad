variables {
  versions = {
    vm = "1.73.0"
  }
}

job "victoria-metrics" {
  datacenters = [
    "syria",
    "asia"
  ]
  namespace = "observability"

  group "victoria-metrics" {
    network {
      port "http" {
        to     = 8428
        static = 8428
      }
    }

    service {
      name = "victoria-metrics"
      port = "http"

      meta {
        alloc_id = NOMAD_ALLOC_ID
      }

      check {
        name     = "VictoriaMetrics HTTP"
        type     = "http"
        protocol = "https"
        path     = "/-/ready"
        interval = "20s"
        timeout  = "2s"

        tls_skip_verify = true
      }
    }

    volume "victoria-metrics" {
      type   = "host"
      source = "victoria-metrics"
    }

    task "victoria-metrics" {
      driver       = "docker"
      user         = "nobody"
      kill_timeout = "10s"

      vault {
        policies = ["victoria-metrics"]
      }

      resources {
        cpu        = 100
        memory     = 128
        memory_max = 258
      }

      volume_mount {
        volume      = "victoria-metrics"
        destination = "/data"
      }

      config {
        image = "victoriametrics/victoria-metrics:v${var.versions.vm}"

        ports = [
          "http"
        ]

        args = [
          "-storageDataPath=/data",
          "-dedup.minScrapeInterval=10s",

          "-tls",
          "-tlsCertFile=/secrets/certs/cert.pem",
          "-tlsKeyFile=/secrets/certs/key.pem",
        ]
      }

      template {
        data = <<-EOH
        {{- with secret "pki/issue/internal" "ttl=7d" "common_name=victoria-metrics.service.consul" -}}
        {{ .Data.private_key }}{{ end }}
        EOH

        destination = "secrets/certs/key.pem"
        change_mode = "restart"
        splay       = "1m"
      }

      template {
        data = <<-EOH
        {{- with secret "pki/issue/internal" "ttl=7d" "common_name=victoria-metrics.service.consul" -}}
        {{ .Data.certificate }}{{ end }}
        EOH

        destination = "secrets/certs/cert.pem"
        change_mode = "restart"
        splay       = "1m"
      }
    }
  }

  group "vmagent" {
    count = 2
    constraint {
      distinct_property = node.datacenter
    }

    ephemeral_disk {
      size   = 500
      sticky = true
    }

    network {
      port "http" {
        to = 8429
      }
    }

    service {
      name = "vmagent"
      port = "http"

      meta {
        alloc_id = NOMAD_ALLOC_ID
      }

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.vmagent.entrypoints=https",
        "traefik.http.routers.vmagent.rule=Host(`vmagent.service.consul`)",
      ]

      check {
        name     = "vmagent HTTP"
        type     = "http"
        path     = "/-/healthy"
        interval = "20s"
        timeout  = "2s"
      }
    }

    task "vmagent" {
      driver = "docker"
      user   = "nobody"

      vault {
        policies = ["vmagent"]
      }

      resources {
        cpu        = 50
        memory     = 128
        memory_max = 256
      }

      config {
        image = "victoriametrics/vmagent:v${var.versions.vm}"

        extra_hosts = [
          "host.docker.internal:host-gateway"
        ]

        ports = [
          "http"
        ]

        args = [
          "-promscrape.config=${NOMAD_TASK_DIR}/config.yml",
          "-remoteWrite.tmpDataPath=${NOMAD_ALLOC_DIR}/data/vmagent-queue",
          "-remoteWrite.maxDiskUsagePerURL=500MB",

          "-remoteWrite.url=https://victoria-metrics.service.consul:8428/vm/api/v1/write",
        ]
      }

      template {
        data          = "{{ key \"configs/vmagent/config.yml\" }}"
        destination   = "local/config.yml"
        change_mode   = "signal"
        change_signal = "SIGHUP"
      }
    }
  }
}
