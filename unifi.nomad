# vim: set ft=hcl sw=2 ts=2 :
job "unifi-controller" {

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

    }

    service {
      name = "unifi"
      port = "web-ui"
    }

    task "unifi" {
      driver = "podman"

      env {
        PUID = "1000"
        PGID = "1000"
      }

      config {
        image = "docker://linuxserver/unifi-controller:version-6.0.45"

        ports = [
          "web-ui",
          "inform",
          "stun",
          "device-discovery"
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
