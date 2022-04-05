variables {
  versions = {
    controller = "7.0.25"
  }

  dc = [
    "syria",
    "asia",
  ]
}

job "unifi" {
  datacenters = var.dc
  namespace   = "services"

  dynamic "group" {
    for_each = { for i, dc in sort(var.dc) : i => dc }
    labels   = ["unifi-${group.value}"]

    content {
      constraint {
        attribute = node.datacenter
        value     = group.value
      }

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
        name = "unifi-${group.value}"
        port = "web-ui"

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.unifi-${group.value}.entrypoints=https",
          "traefik.http.routers.unifi-${group.value}.rule=Host(`unifi-${group.value}.service.consul`)",
          "traefik.http.services.unifi-${group.value}.loadbalancer.serverstransport=skipverify@file",
          "traefik.http.services.unifi-${group.value}.loadbalancer.server.scheme=https"
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
          image = "linuxserver/unifi-controller:version-${var.versions.controller}"

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
          cpu    = 100
          memory = 1024
        }
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

      env {
        UP_UNIFI_CONTROLLER_0_ROLE       = "syria"
        UP_UNIFI_CONTROLLER_0_URL        = "https://unifi-syria.service.consul:8443"
        UP_UNIFI_CONTROLLER_0_SAVE_SITES = false
        UP_UNIFI_CONTROLLER_0_SITE_0     = "syria"

        UP_UNIFI_CONTROLLER_1_ROLE       = "asia"
        UP_UNIFI_CONTROLLER_1_URL        = "https://unifi-asia.service.consul:8443"
        UP_UNIFI_CONTROLLER_1_SAVE_SITES = false
        UP_UNIFI_CONTROLLER_1_SITE_1     = "asia"
      }

      config {
        image      = "golift/unifi-poller"
        force_pull = true

        ports = [
          "http"
        ]
      }

      template {
        data        = <<-EOF
        {{- with secret "secret/unifi/unpoller" -}}
        user = "{{ .Data.data.username }}"
        UP_UNIFI_CONTROLLER_0_USER="{{ .Data.data.username }}"
        UP_UNIFI_CONTROLLER_0_PASS="{{ .Data.data.password }}"
        UP_UNIFI_CONTROLLER_1_USER="{{ .Data.data.username }}"
        UP_UNIFI_CONTROLLER_1_PASS="{{ .Data.data.password }}"
        {{- end -}}
        EOF
        destination = "secrets/creds.env"
        env         = true
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}
