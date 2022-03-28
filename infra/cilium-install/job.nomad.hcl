variables {
  version = "1.11.2"
}

job "cilium-install" {
  datacenters = [
    "syria",
    "asia",
    "pontus",
  ]
  namespace = "infra"
  type      = "sysbatch"

  group "cilium-install" {
    volume "cni" {
      type   = "host"
      source = "cni"
    }

    task "cilium-install" {
      driver = "docker"

      volume_mount {
        volume      = "cni"
        destination = "/host/opt/cni/bin"
      }

      config {
        image      = "cilium/cilium:v${var.version}"
        entrypoint = ["bash"]

        args = [
          "/cni-install.sh"
        ]

        volumes = [
          "/etc/cni/net.d:/host/etc/cni/net.d",
        ]
      }
      resources {
        cpu    = 50
        memory = 20
      }
    }
  }
}
