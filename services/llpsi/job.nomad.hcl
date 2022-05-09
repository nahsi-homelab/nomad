job "llpsi" {
  datacenters = [
    "syria",
  ]
  namespace = "services"

  group "llpsi" {
    count = 1

    network {
      port "http" {
        to = 80
      }
    }

    service {
      name = "llpsi"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.llpsi.entrypoints=public",
        "traefik.http.routers.llpsi.rule=Host(`llpsi.nahsi.dev`)",
      ]

      check {
        name     = "LLPSI HTTP"
        type     = "http"
        port     = "http"
        path     = "/"
        interval = "20s"
        timeout  = "1s"
      }
    }

    task "llpsi" {
      driver = "docker"
      user   = "nobody"

      resources {
        cpu    = 50
        memory = 32
      }

      config {
        image = "nahsihub/llpsi:latest"

        ports = [
          "http",
        ]
      }
    }
  }
}
