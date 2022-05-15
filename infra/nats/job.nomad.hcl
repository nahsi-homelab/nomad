variables {
  versions = {
    nats     = "2.8"
    exporter = "0.9.2"
  }
}

locals {
  certs = {
    "CA"   = "issuing_ca",
    "cert" = "certificate",
    "key"  = "private_key",
  }
}

job "nats" {
  datacenters = [
    "syria",
  ]
  namespace = "infra"

  group "nats" {
    count = 3

    network {
      mode = "bridge"
      port "client" {
        to     = 4222
        static = 4222
      }

      port "cluster" {
        to     = 6222
        static = 6222
      }

      port "monitoring" {}

      port "exporter" {}
    }

    service {
      name = "nats-${meta.nats_index}"
      port = "cluster"

      meta {
        alloc_id = NOMAD_ALLOC_ID
      }

      check {
        name     = "NATS healthz"
        type     = "http"
        port     = "monitoring"
        path     = "/healthz"
        interval = "10s"
        timeout  = "1s"
      }
    }

    volume "nats" {
      type   = "host"
      source = "nats"
    }

    task "nats" {
      driver = "docker"

      vault {
        policies = ["nats"]
      }

      volume_mount {
        volume      = "nats"
        destination = "/data"
      }

      config {
        image      = "nats:${var.versions.nats}-alpine"
        force_pull = true

        ports = [
          "client",
          "monitoring",
          "cluster",
        ]

        args = [
          "--name=nats-${meta.nats_index}",
          "--jetstream",
          "--m=${NOMAD_PORT_monitoring}",
          "--store_dir=/data",
          "--cluster_name=NATS",
          "--cluster=nats://0.0.0.0:6222",
          "--cluster_advertise=nuts-${meta.nats_index}.service.consul:6222",
          "--routes=nats-route://nats-1.service.consul:6222,nats-route://nuts-2.service.consul:6222,nats-route://nats-3.service.consul:6222",
          "--client_advertise=nats-${meta.nats_index}.service.consul",
          /* "--tls", */
          "--tls=false",
          "--tlsverify",
          "--tlscert=/secrets/certs/cert.pem",
          "--tlskey=/secrets/certs/key.pem",
          "--tlscacert=/secrets/certs/CA.pem",
        ]
      }

      dynamic "template" {
        for_each = local.certs
        content {
          data = <<-EOH
          {{- with secret "pki/issue/internal" "ttl=10d" "common_name=nats.service.consul" (env "meta.nats_index" | printf "alt_names=nats-%s.service.consul") (env "attr.unique.network.ip-address" | printf "ip_sans=%s") -}}
          {{ .Data.${template.value} }}
          {{- end -}}
          EOH

          destination = "secrets/certs/${template.key}.pem"
          change_mode = "restart"
          splay       = "5m"
        }
      }

      resources {
        cpu        = 300
        memory     = 128
        memory_max = 256
      }
    }

    task "nats-exporter" {
      driver = "docker"

      resources {
        cpu    = 50
        memory = 64
      }

      config {
        image = "natsio/prometheus-nats-exporter:${var.versions.exporter}"

        args = [
          "-p=${NOMAD_PORT_exporter}",
          "-varz",
          "-jsz=all",
          "http://localhost:${NOMAD_PORT_monitoring}"
        ]

        ports = [
          "exporter",
        ]
      }

      service {
        name = "nats-exporter"
        port = "exporter"

        meta {
          alloc_id = NOMAD_ALLOC_ID
          index    = meta.nats_index
        }
      }
    }
  }
}
