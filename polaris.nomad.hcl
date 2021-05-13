# vim: set ft=hcl sw=2 ts=2 :
job "polaris" {

  datacenters = ["syria"]

  type        = "service"

  group "polaris" {
    network {
      port "http" {
        static = 5050
        to = 5050
      }
    }

    service {
      name = "polaris"
      port = "http"
    }

    task "polaris" {
      driver = "docker"

      config {
        image = "ogarcia/polaris:0.13.4"

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
