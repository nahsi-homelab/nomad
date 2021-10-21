variables {
  versions = {
    dendrite = "v0.5.0"
    promtail = "2.3.0"
  }
}

job "dendrite" {
  datacenters = ["syria"]
  type        = "service"

  group "app-service-api" {
    network {
      port "internal" {
        to = 7777
      }
    }

    task "app-service-api" {
      driver = "docker"
      user = "nobody"

      service {
        name = "dendrite"
        port = "internal"
        address_mode = "host"

        tags = [
          "app-service-api"
        ]
      }

      vault {
        policies = ["dendrite"]
      }

      config {
        image = "matrixdotorg/dendrite-polylith:${var.versions.dendrite}"

        command = "appservice"

        ports = [
          "internal"
        ]

        volumes = [
          "local/:/etc/dendrite"
        ]
      }

      template {
        data = file("dendrite.yaml")
        destination = "local/dendrite.yaml"
      }

      template {
        data =<<EOH
        {{- with secret "secret/dendrite/key" -}}{{ .Data.data.private_key }}{{ end }}
        EOH
        destination = "secrets/matrix.key"
      }

      template {
        data =<<EOH
        {{- with secret "secret/dendrite/key" -}}{{ .Data.data.private_key }}{{ end }}
        EOH
        destination = "local/matrix.key"
      }

      resources {
        memory = 256
      }
    }
  }

  group "client-api" {
    network {
      port "internal" {
        to = 7771
      }

      port "external" {
        to = 8071
      }
    }

    task "client-api" {
      driver = "docker"
      user = "nobody"

      service {
        name = "dendrite"
        port = "external"
        address_mode = "host"

        tags = [
          "client-api",
          "traefik.enable=true",
          "traefik.http.routers.dendrite-client-api.rule=Host(`matrix.service.consul`) && Path(`/_matrix/client`)",
          "traefik.http.routers.dendrite-client-api.tls=true"
        ]
      }

      vault {
        policies = ["dendrite"]
      }

      config {
        image = "matrixdotorg/dendrite-polylith:${var.versions.dendrite}"

        command = "clientapi"

        ports = [
          "internal",
          "external"
        ]

        volumes = [
          "local/:/etc/dendrite"
        ]
      }

      template {
        data = file("dendrite.yaml")
        destination = "local/dendrite.yaml"
      }

      template {
        data =<<EOH
        {{- with secret "secret/dendrite/key" -}}{{ .Data.data.private_key }}{{ end }}
        EOH
        destination = "secrets/matrix.key"
      }

      resources {
        memory = 256
      }
    }
  }

  group "edu-server" {
    network {
      port "internal" {
        to = 7778
      }
    }

    task "edu-server" {
      driver = "docker"
      user = "nobody"

      service {
        name = "dendrite"
        port = "internal"
        address_mode = "host"

        tags = [
          "edu-server"
        ]
      }

      vault {
        policies = ["dendrite"]
      }

      config {
        image = "matrixdotorg/dendrite-polylith:${var.versions.dendrite}"

        command = "eduserver"

        ports = [
          "internal"
        ]

        volumes = [
          "local/:/etc/dendrite"
        ]
      }

      template {
        data = file("dendrite.yaml")
        destination = "local/dendrite.yaml"
      }

      template {
        data =<<EOH
        {{- with secret "secret/dendrite/key" -}}{{ .Data.data.private_key }}{{ end }}
        EOH
        destination = "secrets/matrix.key"
      }

      resources {
        memory = 256
      }
    }
  }

  group "federation-api" {
    network {
      port "internal" {
        to = 7772
      }

      port "external" {
        to = 8072
      }
    }

    task "federation-api" {
      driver = "docker"
      user = "nobody"

      service {
        name = "dendrite"
        port = "external"
        address_mode = "host"

        tags = [
          "federation-api",
          "traefik.enable=true",
          "traefik.http.routers.dendrite-federation-api.rule=Host(`matrix.service.consul`) && Path(`/_matrix/federation`, `/_matrix/key`)",
          "traefik.http.routers.dendrite-federation-api.tls=true"
        ]
      }

      vault {
        policies = ["dendrite"]
      }

      config {
        image = "matrixdotorg/dendrite-polylith:${var.versions.dendrite}"

        command = "federationapi"

        ports = [
          "internal",
          "external"
        ]

        volumes = [
          "local/:/etc/dendrite"
        ]
      }

      template {
        data = file("dendrite.yaml")
        destination = "local/dendrite.yaml"
      }

      template {
        data =<<EOH
        {{- with secret "secret/dendrite/key" -}}{{ .Data.data.private_key }}{{ end }}
        EOH
        destination = "secrets/matrix.key"
      }

      resources {
        memory = 256
      }
    }
  }

  group "federation-sender" {
    network {
      port "internal" {
        to = 7775
      }
    }

    task "federation-sender" {
      driver = "docker"
      user = "nobody"

      service {
        name = "dendrite"
        port = "internal"
        address_mode = "host"

        tags = [
          "federation-sender"
        ]
      }

      vault {
        policies = ["dendrite"]
      }

      config {
        image = "matrixdotorg/dendrite-polylith:${var.versions.dendrite}"

        command = "federationsender"

        ports = [
          "internal"
        ]

        volumes = [
          "local/:/etc/dendrite"
        ]
      }

      template {
        data = file("dendrite.yaml")
        destination = "local/dendrite.yaml"
      }

      template {
        data =<<EOH
        {{- with secret "secret/dendrite/key" -}}{{ .Data.data.private_key }}{{ end }}
        EOH
        destination = "secrets/matrix.key"
      }

      resources {
        memory = 256
      }
    }
  }

  group "key-server" {
    network {
      port "internal" {
        to = 7779
      }
    }

    task "key-server" {
      driver = "docker"
      user = "nobody"

      service {
        name = "dendrite"
        port = "internal"
        address_mode = "host"

        tags = [
          "key-server"
        ]
      }

      vault {
        policies = ["dendrite"]
      }

      config {
        image = "matrixdotorg/dendrite-polylith:${var.versions.dendrite}"

        command = "keyserver"

        ports = [
          "internal"
        ]

        volumes = [
          "local/:/etc/dendrite"
        ]
      }

      template {
        data = file("dendrite.yaml")
        destination = "local/dendrite.yaml"
      }

      template {
        data =<<EOH
        {{- with secret "secret/dendrite/key" -}}{{ .Data.data.private_key }}{{ end }}
        EOH
        destination = "secrets/matrix.key"
      }

      resources {
        memory = 256
      }
    }
  }

  group "media-api" {
    network {
      port "internal" {
        to = 7774
      }

      port "external" {
        to = 8074
      }
    }

    task "media-api" {
      driver = "docker"
      user = "nobody"

      service {
        name = "dendrite"
        port = "external"
        address_mode = "host"

        tags = [
          "media-api",
          "traefik.enable=true",
          "traefik.http.routers.dendrite-media-api.rule=Host(`matrix.service.consul`) && Path(`/_matrix/media`)",
          "traefik.http.routers.dendrite-media-api.tls=true"
        ]
      }

      vault {
        policies = ["dendrite"]
      }

      config {
        image = "matrixdotorg/dendrite-polylith:${var.versions.dendrite}"

        command = "mediaapi"

        ports = [
          "internal",
          "external"
        ]

        volumes = [
          "local/:/etc/dendrite"
        ]
      }

      template {
        data = file("dendrite.yaml")
        destination = "local/dendrite.yaml"
      }

      template {
        data =<<EOH
        {{- with secret "secret/dendrite/key" -}}{{ .Data.data.private_key }}{{ end }}
        EOH
        destination = "secrets/matrix.key"
      }

      resources {
        memory = 256
      }
    }
  }

  group "room-server" {
    network {
      port "internal" {
        to = 7770
      }
    }

    task "room-server" {
      driver = "docker"
      user = "nobody"

      service {
        name = "dendrite"
        port = "internal"
        address_mode = "host"

        tags = [
          "room-server"
        ]
      }

      vault {
        policies = ["dendrite"]
      }

      config {
        image = "matrixdotorg/dendrite-polylith:${var.versions.dendrite}"

        command = "roomserver"

        ports = [
          "internal"
        ]

        volumes = [
          "local/:/etc/dendrite"
        ]
      }

      template {
        data = file("dendrite.yaml")
        destination = "local/dendrite.yaml"
      }

      template {
        data =<<EOH
        {{- with secret "secret/dendrite/key" -}}{{ .Data.data.private_key }}{{ end }}
        EOH
        destination = "secrets/matrix.key"
      }

      resources {
        memory = 256
      }
    }
  }

  group "signing-key-server" {
    network {
      port "internal" {
        to = 7780
      }
    }

    task "signing-key-server" {
      driver = "docker"
      user = "nobody"

      service {
        name = "dendrite"
        port = "internal"
        address_mode = "host"

        tags = [
          "signing-key-server"
        ]
      }

      vault {
        policies = ["dendrite"]
      }

      config {
        image = "matrixdotorg/dendrite-polylith:${var.versions.dendrite}"

        command = "signingkeyserver"

        ports = [
          "internal"
        ]

        volumes = [
          "local/:/etc/dendrite"
        ]
      }

      template {
        data = file("dendrite.yaml")
        destination = "local/dendrite.yaml"
      }

      template {
        data =<<EOH
        {{- with secret "secret/dendrite/key" -}}{{ .Data.data.private_key }}{{ end }}
        EOH
        destination = "secrets/matrix.key"
      }

      resources {
        memory = 256
      }
    }
  }

  group "sync-api" {
    network {
      port "internal" {
        to = 7773
      }

      port "external" {
        to = 8073
      }
    }

    task "sync-api" {
      driver = "docker"
      user = "nobody"

      service {
        name = "dendrite"
        port = "external"
        address_mode = "host"

        tags = [
          "sync-api",
          "traefik.enable=true",
          "traefik.http.routers.dendrite-sync-api.rule=Host(`matrix.service.consul`) && Path(`/_matrix/.*?/(sync|user/.*?/filter/?.*|keys/changes|rooms/.*?/messages)$`, `/_matrix/key`)",
          "traefik.http.routers.dendrite-sync-api.tls=true"
        ]
      }

      vault {
        policies = ["dendrite"]
      }

      config {
        image = "matrixdotorg/dendrite-polylith:${var.versions.dendrite}"

        command = "syncapi"

        ports = [
          "internal",
          "external"
        ]

        volumes = [
          "local/:/etc/dendrite"
        ]
      }

      template {
        data = file("dendrite.yaml")
        destination = "local/dendrite.yaml"
      }

      template {
        data =<<EOH
        {{- with secret "secret/dendrite/key" -}}{{ .Data.data.private_key }}{{ end }}
        EOH
        destination = "secrets/matrix.key"
      }

      resources {
        memory = 256
      }
    }
  }

  group "user-api" {
    network {
      port "internal" {
        to = 7773
      }
    }

    task "user-api" {
      driver = "docker"
      user = "nobody"

      service {
        name = "dendrite"
        port = "internal"
        address_mode = "host"

        tags = [
          "user-api"
        ]
      }

      vault {
        policies = ["dendrite"]
      }

      config {
        image = "matrixdotorg/dendrite-polylith:${var.versions.dendrite}"

        command = "userapi"

        ports = [
          "internal"
        ]

        volumes = [
          "local/:/etc/dendrite"
        ]
      }

      template {
        data = file("dendrite.yaml")
        destination = "local/dendrite.yaml"
      }

      template {
        data =<<EOH
        {{- with secret "secret/dendrite/key" -}}{{ .Data.data.private_key }}{{ end }}
        EOH
        destination = "secrets/matrix.key"
      }

      resources {
        memory = 256
      }
    }
  }
}
