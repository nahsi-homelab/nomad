variables {
  versions = {
    vultr-csi = "0.5.0"
  }

  regions = [
    "ams",
  ]
}

job "vultr-csi-controller" {
  datacenters = ["pontus"]
  namespace   = "infra"

  dynamic "group" {
    for_each = { for i, region in sort(var.regions) : i => region }
    labels   = ["controller-${group.value}"]

    content {
      constraint {
        attribute = meta.vultr_region
        value     = group.value
      }

      task "plugin" {
        driver = "docker"

        vault {
          policies = ["vultr"]
        }

        config {
          image = "vultr/vultr-csi:v${var.versions.vultr-csi}"

          args = [
            "-endpoint=unix:///csi/csi.sock",
            "-token=$VULTR_API_TOKEN",
          ]
        }

        template {
          data = <<-EOF
          VULTR_API_TOKEN={{ with secret "secret/vultr/csi" }}{{ .Data.data.token }}{{ end }}
          EOF

          destination = "secrets/token.env"
          change_mode = "restart"
          env         = true
        }

        csi_plugin {
          id        = "vultr-${group.value}"
          type      = "controller"
          mount_dir = "/csi"
        }

        resources {
          cpu    = 100
          memory = 64
        }
      }
    }
  }
}
