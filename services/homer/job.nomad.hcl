variables {
  versions = {
    homer = "22.02.2"
  }
}

job "homer" {
  datacenters = [
    "syria",
  ]
  namespace = "services"

  group "homer" {
    count = 2

    network {
      port "http" {
        to = 8080
      }
    }

    service {
      name = "homer"
      port = "http"

      tags = [
        "traefik.enable=true",

        "traefik.http.routers.homer.entrypoints=https",
        "traefik.http.routers.homer.rule=Host(`homer.service.consul`)",

        "traefik.http.routers.homer-pub.entrypoints=public",
        "traefik.http.routers.homer-pub.rule=Host(`nahsi.dev`)",
      ]

      check {
        name     = "Homer HTTP"
        type     = "http"
        path     = "/"
        interval = "20s"
        timeout  = "1s"
      }
    }

    task "homer" {
      driver = "docker"

      resources {
        cpu    = 10
        memory = 10
      }

      config {
        image = "b4bz/homer:${var.versions.homer}"

        ports = [
          "http",
        ]

        volumes = [
          "local/config.yml:/www/assets/config.yml:ro",
          "local/homelab.yml:/www/assets/homelab.yml:ro",
        ]
      }

      template {
        data        = file("config.yml")
        destination = "local/config.yml"
      }

      template {
        data        = file("homelab.yml")
        destination = "local/homelab.yml"
      }
    }
  }
}
