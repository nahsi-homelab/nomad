# vim: set ft=hcl sw=2 ts=2 :
job "unifi" {

  datacenters = ["syria"]
  type        = "service"

  group "unifi" {
    network {
      port "web-ui" {
        static = 8443
        to = 8443
      }

      port "inform" {
        static = 8080
        to = 8080
      }

      port "stun" {
        static = 3478
        to = 3478
      }

      port "device-discovery" {
        static = 10001
        to = 10001
      }

      port "l2-discovery" {
        static = 1900
        to = 1900
      }

    }

    service {
      name = "unifi-controller"
      port = "web-ui"

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

    task "unifi" {
      driver = "docker"

      env {
        PUID = "1000"
        PGID = "1000"
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

        volumes = [
          "/mnt/apps/unifi:/config"
        ]
      }

      resources {
        memory = 1024
      }
    }
  }
}
