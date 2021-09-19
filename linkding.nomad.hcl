variables {
  version = "1.8.0"
}

job "linkding" {
  datacenters = ["syria"]
  type        = "service"

  group "linkding" {
    network {
      port "http" {
        to = 9090
      }
    }

    volume "linkding" {
      type = "host"
      source = "linkding"
    }

    task "linkding" {
      driver = "docker"

      service {
        name = "linkding"
        port = "http"
      }

      volume_mount {
        volume = "linkding"
        destination = "/etc/linkding/data"
      }

      resources {
        memory = 256
      }

      env {
        LD_DISABLE_BACKGROUND_TASKS="True"
      }

      config {
        image = "sissbruecker/linkding:${var.version}"

        ports = [
          "http"
        ]
      }
    }
  }
}
