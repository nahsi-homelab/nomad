job "llpsi" {
  datacenters = [
    "syria",
    "asia"
  ]

  constraint {
    distinct_property = "${node.datacenter}"
  }

  group "llpsi" {
    count = 2
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
        "traefik.http.routers.llpsi.rule=Host(`llpsi.service.consul`)",
        "traefik.http.routers.llpsi.tls=true",
        "ingress.enable=true",
        "ingress.http.routers.llpsi.rule=Host(`llpsi.nahsi.dev`)",
        "ingress.http.routers.llpsi.tls=true",
      ]

      check {
        name     = "LLPSI HTTP"
        type     = "http"
        port     = "http"
        path     = "/"
        interval = "20s"
        timeout  = "2s"
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
          "http"
        ]
      }
    }
  }
}
