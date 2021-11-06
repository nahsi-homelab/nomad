variables {
  versions = {
    dendrite = "v0.5.0"
    promtail = "2.3.0"
    caddy = "2.4.5"
  }

  loki = {
    loki-url = "http://loki.service.consul:3100/loki/api/v1/push"
    loki-pipeline-stages =<<EOF
    - multiline:
        firstline: '^time=".*"'
    - regex:
        expression: 'time="(?P<time>)" level=(?P<level>) msg="(?P<msg>\w+)"'
    - timestamp:
        source: time
        format: 2006-01-02T15:04:05.000Z
    EOF
  }
}

job "dendrite" {
  datacenters = ["syria"]
  type        = "service"

  group "well-known" {
    network {
      port "well-known" {
        to = 80
      }
    }

    service {
      name = "matrix"
      port = "well-known"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.dendrite-well-known.rule=Host(`matrix.service.consul`) && Path(`/.well-known/matrix/server`)",
        "traefik.http.routers.dendrite-well-known.tls=true"
      ]
    }

    task "caddy" {
      driver = "docker"

      config {
        image = "caddy:${var.versions.caddy}-alpine"

        ports = [
          "well-known"
        ]

        volumes = [
          "local/Caddyfile:/etc/caddy/Caddyfile"
        ]
      }

      template {
        data =<<EOH
        :80
        respond 200 {
          body "{ \"m.server\": \"matrix.service.consul:443\" }"
          close
        }
        EOH

        destination   = "local/Caddyfile"
        change_mode   = "restart"
      }

      resources {
        memory = 16
      }
    }
  }

  group "client-api" {
    network {
      mode = "bridge"
      port "envoy" {
        to = 9102
      }
      port "envoy-external" {
        to = 9101
      }
    }

    service {
      name = "envoy"
      port = "envoy"

      meta {
        app = "dendrite-client-api"
      }
    }

    service {
      name = "envoy"
      port = "envoy-external"

      meta {
        app = "dendrite-client-api-external"
      }
    }

    service { 
      name = "dendrite-client-api"
      port = 7771

      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "dendrite-user-api"
              local_bind_port = "7781"
            }
            upstreams {
              destination_name = "dendrite-room-server"
              local_bind_port = "7770"
            }
            upstreams {
              destination_name = "dendrite-edu-server"
              local_bind_port = "7778"
            }
            upstreams {
              destination_name = "dendrite-federation-sender"
              local_bind_port = "7775"
            }
            upstreams {
              destination_name = "dendrite-key-server"
              local_bind_port = "7779"
            }
          }
        }
      }
    }

    service {
      name = "dendrite-client-api-external"
      port = 8071

      tags = [
        "traefik.enable=true",
        "traefik.consulcatalog.connect=true",
        "traefik.http.routers.dendrite-client-api.rule=Host(`matrix.service.consul`) && PathPrefix(`/_matrix/client`)"
      ]

      connect {
        sidecar_service {
          proxy {
            config {
              envoy_prometheus_bind_addr = "0.0.0.0:9101"
            }
          }
        }
      }
    }

    task "client-api" {
      driver = "docker"
      user = "nobody"

      vault {
        policies = ["dendrite"]
      }

      config {
        image = "matrixdotorg/dendrite-polylith:${var.versions.dendrite}"
        command = "clientapi"
        volumes = [ "local/:/etc/dendrite" ]
        logging {
          type = "loki"
          config {
            loki-url = var.loki.loki-url
            loki-external-labels = "app=dendrite,subsystem=${NOMAD_TASK_NAME}"
            loki-pipeline-stages = var.loki.loki-pipeline-stages
          }
        }
      }

      template {
        data = file("dendrite.yaml")
        destination = "local/dendrite.yaml"
      }

      template {
        data =<<EOH
        {{- with secret "secret/dendrite/matrix-key" -}}{{ .Data.data.private_key }}{{ end }}
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
      mode = "bridge"
      port "envoy" {
        to = 9102
      }
    }

    service {
      name = "envoy"
      port = "envoy"

      meta {
        app = "dendrite-edu-server"
      }
    }

    service { 
      name = "dendrite-edu-server"
      port = 7778

      connect {
        sidecar_service {}
      }
    }

    task "edu-server" {
      driver = "docker"
      user = "nobody"

      vault {
        policies = ["dendrite"]
      }

      config {
        image = "matrixdotorg/dendrite-polylith:${var.versions.dendrite}"
        command = "eduserver"
        volumes = [ "local/:/etc/dendrite" ]
        logging {
          type = "loki"
          config {
            loki-url = var.loki.loki-url
            loki-external-labels = "app=dendrite,subsystem=${NOMAD_TASK_NAME}"
            loki-pipeline-stages = var.loki.loki-pipeline-stages
          }
        }
      }

      template {
        data = file("dendrite.yaml")
        destination = "local/dendrite.yaml"
      }

      template {
        data =<<EOH
        {{- with secret "secret/dendrite/matrix-key" -}}{{ .Data.data.private_key }}{{ end }}
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
      mode = "bridge"
      port "envoy" {
        to = 9102
      }
      port "envoy-external" {
        to = 9101
      }
    }

    service {
      name = "envoy"
      port = "envoy"

      meta {
        app = "dendrite-federation-api"
      }
    }

    service {
      name = "envoy"
      port = "envoy-external"

      meta {
        app = "dendrite-federation-api-external"
      }
    }

    service { 
      name = "dendrite-federation-api"
      port = 7772

      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "dendrite-user-api"
              local_bind_port = "7781"
            }
            upstreams {
              destination_name = "dendrite-room-server"
              local_bind_port = "7770"
            }
            upstreams {
              destination_name = "dendrite-edu-server"
              local_bind_port = "7778"
            }
            upstreams {
              destination_name = "dendrite-federation-sender"
              local_bind_port = "7775"
            }
            upstreams {
              destination_name = "dendrite-key-server"
              local_bind_port = "7779"
            }
          }
        }
      }
    }

    service { 
      name = "dendrite-federation-api-external"
      port = 8072

      tags = [
        "traefik.enable=true",
        "traefik.consulcatalog.connect=true",
        "traefik.http.routers.dendrite-federation-api.rule=Host(`matrix.service.consul`) && PathPrefix(`/_matrix/federation`, `/_matrix/key`)",
      ]

      connect {
        sidecar_service {
          proxy {
            config {
              envoy_prometheus_bind_addr = "0.0.0.0:9101"
            }
          }
        }
      }
    }

    task "federation-api" {
      driver = "docker"
      user = "nobody"

      vault {
        policies = ["dendrite"]
      }

      config {
        image = "matrixdotorg/dendrite-polylith:${var.versions.dendrite}"
        command = "federationapi"
        volumes = [ "local/:/etc/dendrite" ]
        logging {
          type = "loki"
          config {
            loki-url = var.loki.loki-url
            loki-external-labels = "app=dendrite,subsystem=${NOMAD_TASK_NAME}"
            loki-pipeline-stages = var.loki.loki-pipeline-stages
          }
        }
      }

      template {
        data = file("dendrite.yaml")
        destination = "local/dendrite.yaml"
      }

      template {
        data =<<EOH
        {{- with secret "secret/dendrite/matrix-key" -}}{{ .Data.data.private_key }}{{ end }}
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
      mode = "bridge"
      port "envoy" {
        to = 9102
      }
    }

    service {
      name = "envoy"
      port = "envoy"

      meta {
        app = "dendrite-federation-sender"
      }
    }

    service { 
      name = "dendrite-federation-sender"
      port = 7775

      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "dendrite-room-server"
              local_bind_port = "7770"
            }
            upstreams {
              destination_name = "dendrite-key-server"
              local_bind_port = "7779"
            }
          }
        }
      }
    }

    task "federation-sender" {
      driver = "docker"
      user = "nobody"

      vault {
        policies = ["dendrite"]
      }

      config {
        image = "matrixdotorg/dendrite-polylith:${var.versions.dendrite}"
        command = "federationsender"
        volumes = [ "local/:/etc/dendrite" ]
        logging {
          type = "loki"
          config {
            loki-url = var.loki.loki-url
            loki-external-labels = "app=dendrite,subsystem=${NOMAD_TASK_NAME}"
            loki-pipeline-stages = var.loki.loki-pipeline-stages
          }
        }
      }

      template {
        data = file("dendrite.yaml")
        destination = "local/dendrite.yaml"
      }

      template {
        data =<<EOH
        {{- with secret "secret/dendrite/matrix-key" -}}{{ .Data.data.private_key }}{{ end }}
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
      mode = "bridge"
      port "envoy" {
        to = 9102
      }
    }

    service {
      name = "envoy"
      port = "envoy"

      meta {
        app = "dendrite-key-server"
      }
    }

    service { 
      name = "dendrite-key-server"
      port = 7779

      connect {
        sidecar_service {}
      }
    }

    task "key-server" {
      driver = "docker"
      user = "nobody"

      vault {
        policies = ["dendrite"]
      }

      config {
        image = "matrixdotorg/dendrite-polylith:${var.versions.dendrite}"
        command = "keyserver"
        volumes = [ "local/:/etc/dendrite" ]
        logging {
          type = "loki"
          config {
            loki-url = var.loki.loki-url
            loki-external-labels = "app=dendrite,subsystem=${NOMAD_TASK_NAME}"
            loki-pipeline-stages = var.loki.loki-pipeline-stages
          }
        }
      }

      template {
        data = file("dendrite.yaml")
        destination = "local/dendrite.yaml"
      }

      template {
        data =<<EOH
        {{- with secret "secret/dendrite/matrix-key" -}}{{ .Data.data.private_key }}{{ end }}
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
      mode = "bridge"
      port "envoy" {
        to = 9102
      }
      port "envoy-external" {
        to = 9101
      }
    }

    service {
      name = "envoy"
      port = "envoy"

      meta {
        app = "dendrite-media-api"
      }
    }

    service {
      name = "envoy"
      port = "envoy-external"

      meta {
        app = "dendrite-media-api-external"
      }
    }

    service {
      name = "dendrite-media-api"
      port = 7774

      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "dendrite-user-api"
              local_bind_port = "7781"
            }
          }
        }
      }
    }

    service {
      name = "dendrite-media-api-external"
      port = 8074

      tags = [
        "traefik.enable=true",
        "traefik.consulcatalog.connect=true",
        "traefik.http.routers.dendrite-media-api.rule=Host(`matrix.service.consul`) && PathPrefix(`/_matrix/media`)",
      ]

      connect {
        sidecar_service {
          proxy {
            config {
              envoy_prometheus_bind_addr = "0.0.0.0:9101"
            }
          }
        }
      }
    }

    task "media-api" {
      driver = "docker"
      user = "nobody"

      vault {
        policies = ["dendrite"]
      }

      config {
        image = "matrixdotorg/dendrite-polylith:${var.versions.dendrite}"
        command = "mediaapi"
        volumes = [ "local/:/etc/dendrite" ]
        logging {
          type = "loki"
          config {
            loki-url = var.loki.loki-url
            loki-external-labels = "app=dendrite,subsystem=${NOMAD_TASK_NAME}"
            loki-pipeline-stages = var.loki.loki-pipeline-stages
          }
        }
      }

      template {
        data = file("dendrite.yaml")
        destination = "local/dendrite.yaml"
      }

      template {
        data =<<EOH
        {{- with secret "secret/dendrite/matrix-key" -}}{{ .Data.data.private_key }}{{ end }}
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
      mode = "bridge"
      port "envoy" {
        to = 9102
      }
    }

    service {
      name = "envoy"
      port = "envoy"

      meta {
        app = "dendrite-room-server"
      }
    }

    service {
      name = "dendrite-room-server"
      port = 7770

      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "dendrite-key-server"
              local_bind_port = "7779"
            }
          }
        }
      }
    }

    task "room-server" {
      driver = "docker"
      user = "nobody"

      vault {
        policies = ["dendrite"]
      }

      config {
        image = "matrixdotorg/dendrite-polylith:${var.versions.dendrite}"
        command = "roomserver"
        volumes = [ "local/:/etc/dendrite" ]
        logging {
          type = "loki"
          config {
            loki-url = var.loki.loki-url
            loki-external-labels = "app=dendrite,subsystem=${NOMAD_TASK_NAME}"
            loki-pipeline-stages = var.loki.loki-pipeline-stages
          }
        }
      }

      template {
        data = file("dendrite.yaml")
        destination = "local/dendrite.yaml"
      }

      template {
        data =<<EOH
        {{- with secret "secret/dendrite/matrix-key" -}}{{ .Data.data.private_key }}{{ end }}
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
      mode = "bridge"
      port "envoy" {
        to = 9102
      }
    }

    service {
      name = "envoy"
      port = "envoy"

      meta {
        app = "dendrite-signing-key-server"
      }
    }

    service {
      name = "dendrite-signing-key-server"
      port = 7780

      connect {
        sidecar_service {}
      }
    }

    task "signing-key-server" {
      driver = "docker"
      user = "nobody"

      vault {
        policies = ["dendrite"]
      }

      config {
        image = "matrixdotorg/dendrite-polylith:${var.versions.dendrite}"
        command = "signingkeyserver"
        volumes = [ "local/:/etc/dendrite" ]
        logging {
          type = "loki"
          config {
            loki-url = var.loki.loki-url
            loki-external-labels = "app=dendrite,subsystem=${NOMAD_TASK_NAME}"
            loki-pipeline-stages = var.loki.loki-pipeline-stages
          }
        }
      }

      template {
        data = file("dendrite.yaml")
        destination = "local/dendrite.yaml"
      }

      template {
        data =<<EOH
        {{- with secret "secret/dendrite/matrix-key" -}}{{ .Data.data.private_key }}{{ end }}
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
      mode = "bridge"
      port "envoy" {
        to = 9102
      }
      port "envoy-external" {
        to = 9101
      }
    }

    service {
      name = "envoy"
      port = "envoy"

      meta {
        app = "dendrite-sync-api"
      }
    }

    service {
      name = "envoy"
      port = "envoy-external"

      meta {
        app = "dendrite-sync-api-external"
      }
    }

    service {
      name = "dendrite-sync-api"
      port = 7773

      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "dendrite-user-api"
              local_bind_port = "7781"
            }
            upstreams {
              destination_name = "dendrite-room-server"
              local_bind_port = "7770"
            }
          }
        }
      }
    }

    service {
      name = "dendrite-sync-api-external"
      port = 8073

      tags = [
        "traefik.enable=true",
        "traefik.consulcatalog.connect=true",
        "traefik.http.routers.dendrite-sync-api.rule=Host(`matrix.service.consul`) && PathPrefix(`/_matrix/client/?.*/(sync|user/.*?/filter/?.*|keys/changes|rooms/.*?/messages)$`)"
      ]

      connect {
        sidecar_service {
          proxy {
            config {
              envoy_prometheus_bind_addr = "0.0.0.0:9101"
            }
          }
        }
      }
    }

    task "sync-api" {
      driver = "docker"
      user = "nobody"

      vault {
        policies = ["dendrite"]
      }

      config {
        image = "matrixdotorg/dendrite-polylith:${var.versions.dendrite}"
        command = "syncapi"
        volumes = [ "local/:/etc/dendrite" ]
        logging {
          type = "loki"
          config {
            loki-url = var.loki.loki-url
            loki-external-labels = "app=dendrite,subsystem=${NOMAD_TASK_NAME}"
            loki-pipeline-stages = var.loki.loki-pipeline-stages
          }
        }
      }

      template {
        data = file("dendrite.yaml")
        destination = "local/dendrite.yaml"
      }

      template {
        data =<<EOH
        {{- with secret "secret/dendrite/matrix-key" -}}{{ .Data.data.private_key }}{{ end }}
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
      mode = "bridge"
      port "envoy" {
        to = 9102
      }
    }

    service {
      name = "envoy"
      port = "envoy"

      meta {
        app = "dendrite-user-api"
      }
    }

    service {
      name = "dendrite-user-api"
      port = 7781

      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "dendrite-key-server"
              local_bind_port = "7779"
            }
          }
        }
      }
    }

    task "user-api" {
      driver = "docker"
      user = "nobody"

      vault {
        policies = ["dendrite"]
      }

      config {
        image = "matrixdotorg/dendrite-polylith:${var.versions.dendrite}"
        command = "userapi"
        volumes = [ "local/:/etc/dendrite" ]
        logging {
          type = "loki"
          config {
            loki-url = var.loki.loki-url
            loki-external-labels = "app=dendrite,subsystem=${NOMAD_TASK_NAME}"
            loki-pipeline-stages = var.loki.loki-pipeline-stages
          }
        }
      }

      template {
        data = file("dendrite.yaml")
        destination = "local/dendrite.yaml"
      }

      template {
        data =<<EOH
        {{- with secret "secret/dendrite/matrix-key" -}}{{ .Data.data.private_key }}{{ end }}
        EOH
        destination = "secrets/matrix.key"
      }

      resources {
        memory = 256
      }
    }
  }
}
