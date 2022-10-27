job "libreddit" {
  datacenters = ["syria"]
  namespace   = "services"

  group "libreddit" {
    network {
      port "http" {
        to = 8080
      }
    }

    service {
      name = "libreddit"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.libreddit.entrypoints=public",
        "traefik.http.routers.libreddit.rule=Host(`libreddit.nahsi.dev`)",
      ]
    }

    task "libreddit" {
      driver = "docker"
      user   = "nobody"

      env {
        # https://github.com/spikecodes/libreddit#change-default-settings
        LIBREDDIT_DEFAULT_THEME = "dark"
      }

      config {
        image      = "spikecodes/libreddit"
        force_pull = true
        ports      = ["http"]
      }

      resources {
        cpu        = 100
        memory     = 128
        memory_max = 256
      }
    }
  }
}
