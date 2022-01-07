job "unifi" {
  datacenters = ["syria"]
  type        = "service"

  group "unifi" {
    network {
      port "web-ui" {
        static = 8443
        to     = 8443
      }

      port "inform" {
        static = 8080
        to     = 8080
      }

      port "stun" {
        static = 3478
        to     = 3478
      }

      port "device-discovery" {
        static = 10001
        to     = 10001
      }

      port "l2-discovery" {
        static = 1900
        to     = 1900
      }

    }

    service {
      name = "unifi"
      port = "web-ui"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.unifi.tls=true",
        "traefik.http.routers.unifi.rule=Host(`unifi.service.consul`)",
        "traefik.http.services.unifi.loadbalancer.serverstransport=skipverify@file",
        "traefik.http.services.unifi.loadbalancer.server.scheme=https"
      ]

      check {
        type     = "http"
        protocol = "https"
        path     = "/status"
        port     = "web-ui"
        interval = "30s"
        timeout  = "2s"

        tls_skip_verify = true
      }
    }

    volume "unifi" {
      type   = "host"
      source = "unifi"
    }

    task "unifi" {
      driver = "docker"

      env {
        PUID = "1000"
        PGID = "1000"
      }

      volume_mount {
        volume      = "unifi"
        destination = "/config"
      }

      config {
        image = "linuxserver/unifi-controller:version-6.2.26"

        ports = [
          "web-ui",
          "inform",
          "stun",
          "device-discovery",
          "l2-discovery"
        ]

        network_mode = "host"
      }

      resources {
        memory = 1024
      }
    }
  }

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
        image      = "golift/unifi-poller"
        force_pull = true

        ports = [
          "http"
        ]

        volumes = [
          "local/unpoller.conf:/etc/unifi-poller/up.conf"
        ]
      }

      template {
        data        = <<EOH
        [unifi.defaults]
          url = "https://unifi.service.consul:8443"
          verify_ssl = false
          user = "{{ with secret "secret/unifi/unpoller" }}{{ .Data.data.username }}{{ end }}"
          pass = "{{ with secret "secret/unifi/unpoller" }}{{ .Data.data.password }}{{ end }}"

          save_sites = false
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
