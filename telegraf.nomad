# vim: set ft=hcl sw=2 ts=2 :
job "telegraf" {
  datacenters = ["syria"]

  type        = "system"

  group "telegraf" {

    network {
      port "prometheus" {
        static = 9271
        to = 9271
      }
    }

    service {
      name = "telegraf"
      port = "prometheus"
    }

    task "telegraf" {
      driver = "exec"

      config {
        command = "local/telegraf-1.17.3/usr/bin/telegraf"
        args = ["--config", "local/telegraf.conf"]
      }

      artifact {
        source = "https://dl.influxdata.com/telegraf/releases/telegraf-1.17.3_linux_amd64.tar.gz"
        destination = "local"

        options {
          checksum = "sha256:b36305454045abbef36f069d623622d0e8ce537ac6e62996f6585c9caa4fdfd7"
        }
      }

      template {
        data =<<EOH
[agent]
  interval = "15s"
  ommit_hostname = true

[[outputs.prometheus_client]]
  listen = ":9271"
  metric_version = 2
  path = "/metrics"
  expiration_interval = "30s"

[[inputs.internal]]

[[inputs.system]]

[[inputs.cpu]]
  percpu = true
  totalcpu = true
  collect_cpu_time = false

[[inputs.mem]]

[[inputs.disk]]
  ignore_fs = [
    "tmpfs",
    "devtmpfs",
    "devfs",
    "iso9660",
    "overlay",
    "aufs",
    "squashfs"
  ]

[[inputs.diskio]]

[[inputs.swap]]

[[inputs.kernel]]

[[inputs.processes]]
EOH

        destination = "local/telegraf.conf"
      }

      resources {
        cpu    = 200
        memory = 150
      }
    }
  }
}
