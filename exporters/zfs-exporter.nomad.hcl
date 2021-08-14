variables {
  version = "1.0.1"
  checksum = "acec9bb17ac05b882044b147b7f1fd6c54f2863ad57baaf0456e81310e0ae789"
}

job "zfs-exporter" {
  datacenters = ["syria", "asia"]
  type        = "system"

  group "zfs-exporter" {

    network {
      port "http" {}
    }

    service {
      name = "zfs-exporter"
      port = "http"
    }

    task "zfs-exporter" {
      driver = "raw_exec"

      config {
        command = "local/zfs_exporter-${var.version}.linux-amd64/zfs_exporter"
        args = [
          "--web.listen-address=:${NOMAD_PORT_http}"
        ]
      }

      artifact {
        source = "https://github.com/pdf/zfs_exporter/releases/download/v${var.version}/zfs_exporter-${var.version}.linux-amd64.tar.gz"
        destination = "local/"

        options {
          checksum = "sha256:${var.checksum}"
        }
      }

      resources {
        memory = 128
      }
    }
  }
}
