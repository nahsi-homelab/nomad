job "unpoller" {
  datacenters = ["syria"]
  type        = "service"

  group "unpoller" {
    network {
      port "http" {
        to = 9130
      }
    }

    service {
      name = "unpoller"
      port = "http"
    }

    task "unpoller" {
      driver = "docker"

      vault {
        policies = ["unpoller"]
      }

      config {
        image = "golift/unifi-poller"
        force_pull = true

        ports = [
          "http"
        ]

        volumes = [
          "local/unpoller.conf:/etc/unifi-poller/up.conf"
        ]
      }

      template {
        data = <<EOH
        [unifi.defaults]
          url = "https://unifi-controller.service.consul:8443"
          verify_ssl = false
          user = "{{ with secret "secret/unifi/unpoller" }}{{ .Data.data.username }}{{ end }}"
          pass = "{{ with secret "secret/unifi/unpoller" }}{{ .Data.data.password }}{{ end }}"

          save_sites = true
          save_ids = false
          save_events = false
          save_alarms = false
          save_dpi = false

          sites = ["all"]

        [prometheus]
          disable = false
          http_listen = "0.0.0.0:9130"
          report_errors = false
          dead_ports = true

        [influxdb]
          disable = true
        EOH
        destination = "local/unpoller.conf"
      }

      resources {
        memory = 128
      }
    }
  }
}
