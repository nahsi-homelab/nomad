job "github-runner" {
  datacenters = [
    "syria"
  ]

  update {
    max_parallel      = 1
    healthy_deadline  = "15m"
    progress_deadline = "20m"
  }

  group "qemu" {
    ephemeral_disk {
      migrate = true
      sticky  = true
      size    = 1000
    }

    network {
      mode = "bridge"
      port "novnc" {}
    }

    task "qemu" {
      driver = "qemu"

      resources {
        cores  = 2
        memory = 2048
      }

      config {
        image_path  = "alloc/data/github-runner.img"
        accelerator = "kvm"

        graceful_shutdown = true

        args = [
          "-vnc", "127.0.0.1:1",
        ]
      }

      artifact {
        source      = "https://boxes:boxes@sftpgo.service.consul/dav/local/github-runner/github-runner.img"
        destination = "alloc/data/"
      }
    }

    task "novnc" {
      driver = "docker"
      user   = "999"

      lifecycle {
        hook    = "poststart"
        sidecar = true
      }

      resources {
        cpu    = 10
        memory = 32
      }

      env {
        NOVNC_PORT   = "${NOMAD_PORT_novnc}"
        NOVNC_TARGET = "127.0.0.1:5901"
      }

      config {
        image = "nahsihub/novnc"
        ports = ["novnc"]
      }
    }
  }
}
