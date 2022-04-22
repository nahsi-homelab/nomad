variables {
  versions = {
    vultr-csi = "0.5.0"
  }

  regions = [
    "ams",
  ]
}

job "vultr-csi-nodes" {
  datacenters = ["pontus"]
  namespace   = "infra"
  type        = "system"

  dynamic "group" {
    for_each = { for i, region in sort(var.regions) : i => region }
    labels   = ["node-${group.value}"]

    content {
      constraint {
        attribute = meta.vultr_region
        value     = group.value
      }

      task "plugin" {
        driver = "docker"

        config {
          image = "vultr/vultr-csi:v${var.versions.vultr-csi}"

          privileged = true

          args = [
            "-endpoint=unix:///csi/csi.sock",
          ]
        }

        csi_plugin {
          id        = "vultr-${group.value}"
          type      = "node"
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
