variables {
  versions = {
    tempo = "1.1.0"
    promtail = "2.3.0"
  }
}

job "tempo" {
  datacenters = ["syria"]
  namespace   = "infra"
  type        = "service"

  group "tempo" {
    ephemeral_disk {}
    network {
      port "tempo" {
        to = 3200
        static = 3200
      }

      port "tempo-grpc" {
        to = 9095
        static = 9095
      }

      /* port "promtail" { */
      /*   to = 3000 */
      /* } */
    }

    /* volume "tempo" { */
    /*   type   = "host" */
    /*   source = "tempo" */
    /* } */

    task "tempo" {
      driver = "docker"
      user   = "nobody"

      service {
        name = "tempo"
        port = "tempo"

        check {
          name     = "Tempo HTTP"
          type     = "http"
          path     = "/ready"
          interval = "10s"
          timeout  = "2s"
        }
      }

      /* volume_mount { */
      /*   volume      = "tempo" */
      /*   destination = "/tempo" */
      /* } */

      config {
        image = "grafana/tempo:${var.versions.tempo}"

        ports = [
          "tempo",
          "tempo-grpc"
        ]

        args = [
          "-config.file=/local/tempo.yml"
        ]
      }

      template {
        data = file("tempo.yml")
        destination = "local/tempo.yml"
      }
    }
  }
}
