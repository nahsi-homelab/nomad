variables {
  versions = {
    controller = "1.6.3"
  }
}

job "democratic-controller" {
  datacenters = ["syria"]
  namespace   = "infra"

  group "controller" {
    task "controller" {
      driver = "docker"

      config {
        image = "democraticcsi/democratic-csi:v${var.versions.controller}"

        privileged = true

        args = [
          "--log-level=info",
          "--driver-config-file=${NOMAD_TASK_DIR}/config.yml",
          "--csi-name=org.democratic-csi.zfs-local-dataset",
          "--csi-version=1.5.0",
          "--csi-mode=controller",
          "--server-socket=/csi/csi.sock",
        ]
      }

      csi_plugin {
        id        = "zfs-local-dataset"
        type      = "controller"
        mount_dir = "/csi"
      }

      template {
        data        = file("zfs-local-dataset.yml")
        destination = "${NOMAD_TASK_DIR}/config.yml"
      }

      resources {
        cpu    = 30
        memory = 50
      }
    }
  }
}
