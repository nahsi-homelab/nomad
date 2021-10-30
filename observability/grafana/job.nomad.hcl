variables {
  versions = {
    grafana-agent = "0.20.0"
    promtail = "2.3.0"
  }
}

job "grafana-agent" {
  datacenters = ["syria", "asia"]
  namespace   = "infra"
  type        = "system"

  group "grafana-agent" {
    network {
      port "agent" {
        to = 3020
      }
      port "zipkin" {
        to = 9411
        static = 9411
      }
    }

    service {
      name = "grafana-agent"
      port = "agent"

      check {
        name     = "Agent HTTP"
        type     = "http"
        path     = "/ready"
        interval = "10s"
        timeout  = "2s"
      }
    }


    task "grafana-agent" {
      driver = "docker"
      user   = "nobody"

      config {
        image = "grafana/agent:v${var.versions.grafana-agent}"

        ports = [
          "agent",
          "zipkin"
        ]

        args = [
          "-config.file=/local/agent.yml"
        ]
      }

      template {
        data = file("agent.yml")
        destination = "local/agent.yml"
      }
    }
  }
}
