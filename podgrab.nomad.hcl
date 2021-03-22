# vim: set ft=hcl sw=2 ts=2 :
job "podgrab" {

  datacenters = ["syria"]

  type        = "service"

  group "podgrab" {

    network {
      port "http" {
        static = 8081
        to = 8080
      }
    }

    service {
      name = "podgrab"
      port = "http"
    }

    task "podgrab" {
      driver = "podman"

      config {
        image = "docker://akhilrex/podgrab"

        ports = [
          "http"
        ]

        volumes = [
          "/home/nahsi/media/podcasts:/assets",
          "/mnt/apps/podgrab/config:/config"
        ]
      }

      resources {
        cpu = 300
        memory = 256
      }
    }
  }
}
