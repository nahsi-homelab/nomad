variables {
  versions = {
    seaweedfs = "latest"
  }
}

job "seaweedfs-csi" {
  datacenters = [
    "syria",
  ]
  namespace = "infra"
  type      = "system"

  update {
    max_parallel = 1
    stagger      = "1m"
  }

  group "monolith" {
    ephemeral_disk {
      size = 1100
    }

    task "plugin" {
      driver = "docker"

      config {
        image      = "chrislusf/seaweedfs-csi-driver:${var.versions.seaweedfs}"
        force_pull = true

        args = [
          "--endpoint=unix://csi/csi.sock",
          "--filer=seaweedfs-filer.service.consul:9533",
          "--nodeid=${node.unique.name}",
          "--cacheCapacityMB=1024",
          "--cacheDir=${NOMAD_ALLOC_DIR}/data/cache",
        ]

        privileged = true
        cap_add = [
          "SYS_ADMIN",
        ]
      }

      csi_plugin {
        id        = "seaweedfs"
        type      = "monolith"
        mount_dir = "/csi"
      }

      resources {
        cpu        = 100
        memory     = 512
        memory_max = 1024
      }
    }
  }
}
