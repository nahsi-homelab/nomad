job "podgrab" {

  datacenters = ["syria"]
  type        = "service"

  group "podgrab" {
    network {
      port "http" {
        to = 8080
      }
    }

    service {
      name = "podgrab-app"
      port = "http"
    }

    volume "podgrab" {
      type = "host"
      source = "podgrab"
    }

    task "podgrab" {
      driver = "docker"
      user = "nobody"

      env {
        CHECK_REQUENCY=240
      }

      volume_mount {
        volume = "podgrab"
        destination = "/config"
      }

      config {
        image = "akhilrex/podgrab"

        ports = [
          "http"
        ]

        volumes = [
          "/home/nahsi/media/podcasts:/assets"
        ]
      }

      resources {
        memory = 128
      }
    }
  }
}
