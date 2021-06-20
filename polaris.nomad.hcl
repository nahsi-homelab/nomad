# vim: set ft=hcl sw=2 ts=2 :
job "polaris" {

  datacenters = ["syria"]

  type        = "service"

  group "polaris" {
    network {
      port "http" {}
    }

    service {
      name = "polaris-app"
      port = "http"
    }

    task "polaris" {
      driver = "docker"

      env {
        POLARIS_PORT = "${NOMAD_PORT_http}"
      }

      config {
        image = "ogarcia/polaris:0.13.5"

        ports = [
          "http"
        ]

        volumes = [
          "/home/nahsi/media/music/:/music:ro",
          "/mnt/apps/polaris/cache:/var/cache/polaris",
          "/mnt/apps/polaris/data:/var/lib/polaris",
        ]
      }

      resources {
        cpu = 100
        memory = 300
      }
    }
  }
}
