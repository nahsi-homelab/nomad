variables {
  version = "1.2.2"
  checksum = "344bd4c0bbd66ff78f14486ec48b89c248139cdd485e992583ea30e89e0e5390"
}

job "node-exporter" {
  datacenters = ["syria", "asia"]
  type        = "system"

  group "node-exporter" {

    network {
      port "http" {}
    }

    service {
      name = "node-exporter"
      port = "http"
    }

    task "node-exporter" {
      driver = "raw_exec"

      config {
        command = "local/node_exporter-${var.version}.linux-amd64/node_exporter"
        args = [
          "--web.listen-address=:${NOMAD_PORT_http}",
          "--collector.disable-defaults",
          "--collector.cpu",
          "--collector.cpufreq",
          "--collector.diskstats",
          "--collector.filefd",
          "--collector.filesystem",
          "--collector.hwmon",
          "--collector.loadavg",
          "--collector.nvme",
          "--collector.pressure",
          "--collector.schedstat",
          "--collector.stat",
          "--collector.uname",
          "--collector.zfs"
        ]
      }

      artifact {
        source = "https://github.com/prometheus/node_exporter/releases/download/v${var.version}/node_exporter-${var.version}.linux-amd64.tar.gz"
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
