variables {
  versions = {
    prometheus = "2.37.0"
  }
}

job "prometheus" {
  datacenters = [
    "syria",
  ]
  namespace   = "observability"

  group "prometheus" {
    count = 2

    ephemeral_disk {
      size    = 1000
      migrate = true
      sticky  = true
    }

    network {
      port "http" {
        to     = 9090
      }
    }

    service {
      name = "prometheus"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.prometheus.rule=Host(`prometheus.service.consul`)",
      ]

      check {
        name     = "Prometheus HTTP"
        type     = "http"
        path     = "/-/healthy"
        interval = "10s"
        timeout  = "1s"
      }
    }

    task "prometheus" {
      driver = "docker"
      user   = "nobody"

      vault {
        policies = [
          "prometheus",
        ]
      }

      config {
        image = "prom/prometheus:v${var.versions.prometheus}"

        ports = [
          "http",
        ]

        args = [
          "--web.listen-address=0.0.0.0:9090",
          "--config.file=/local/config.yml",
          "--storage.tsdb.retention.time=1d",
          "--storage.tsdb.path=/prometheus",
        ]
      }

      template {
        data          = file("config.yml")
        destination   = "local/config.yml"
      }

      resources {
        cpu        = 300
        memory     = 512
        memory_max = 1024
      }
    }
  }
}
