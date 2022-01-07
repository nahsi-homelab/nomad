variables {
  versions = {
    homer = "21.09.2"
  }
}

job "homer" {
  datacenters = [
    "syria",
    "asia"
  ]
  namespace = "services"

  update {
    max_parallel = 1
    stagger      = "20s"
    auto_revert  = true
  }

  constraint {
    operator = "distinct_hosts"
    value    = "true"
  }

  group "private" {
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
        "traefik.entrypoints=https",
        "traefik.http.routers.homer.rule=Host(`homer.service.consul`)",
        "traefik.http.routers.homer.tls=true"
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
          "http"
        ]
        volumes = [
          "local/config.yml:/www/assets/config.yml"
        ]
      }

      template {
        data        = file("private.yml")
        destination = "local/config.yml"
      }
    }
  }

  group "public" {
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
        "ingress.enable=true",
        "ingress.entrypoints=https",
        "ingress.http.routers.homer.rule=Host(`nahsi.dev`)",
        "ingress.http.routers.homer.tls=true"
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
          "http"
        ]
        volumes = [
          "local/config.yml:/www/assets/config.yml"
        ]
      }

      template {
        data        = file("public.yml")
        destination = "local/config.yml"
      }
    }
  }
}
