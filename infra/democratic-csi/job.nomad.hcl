variables {
  versions = {
    csi = "1.6.3"
  }
}

job "democratic-csi" {
  datacenters = ["syria"]
  namespace   = "infra"
  /* type        = "system" */

  constraint {
    attribute = node.unique.name
    value = "palmyra"
  }

  group "monolith" {
    task "monolith" {
      driver = "docker"

      env {
        CSI_NODE_ID = node.unique.name
      }

      config {
        image    = "democraticcsi/democratic-csi:v${var.versions.csi}"
        hostname = node.unique.name

        privileged = true
        ipc_mode   = "host"
        network_mode = "host"

        args = [
          "--log-level=info",
          "--driver-config-file=${NOMAD_TASK_DIR}/config.yml",
          "--csi-name=org.democratic-csi.zfs-local-dataset",
          "--csi-version=1.5.0",
          "--csi-mode=controller",
          "--csi-mode=node",
          "--server-socket=/csi/csi.sock",
        ]

        mount {
          type     = "bind"
          target   = "/host"
          source   = "/"
          readonly = true
        }
      }

      csi_plugin {
        id        = "zfs-local-dataset"
        type      = "monolith"
        mount_dir = "/csi"
      }

      template {
        data        = file("zfs-local-dataset.yml")
        destination = "${NOMAD_TASK_DIR}/config.yml"
        left_delimiter = "[["
        right_delimiter = "]]"
      }

      resources {
        cpu    = 30
        memory = 50
      }
    }
  }
}
