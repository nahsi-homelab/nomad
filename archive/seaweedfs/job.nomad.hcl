variables {
  log_level = "1" # log level [0|1|2|3|4]
  versions = {
    seaweedfs = "3.00"
  }
}

job "seaweedfs" {
  datacenters = [
    "syria",
  ]
  namespace = "infra"

  group "master" {
    count = 3

    update {
      max_parallel = 1
      stagger      = "2m"
    }

    migrate {
      min_healthy_time = "2m"
    }

    network {
      port "http" {
        to     = 9333
        static = 9333
      }
      port "grpc" {
        to     = 19333
        static = 19333
      }
      port "metrics" {}
    }

    volume "master" {
      type   = "host"
      source = "seaweedfs-master"
    }

    task "master" {
      driver = "docker"
      user   = "nobody"

      kill_signal  = "SIGINT"
      kill_timeout = "90s"

      volume_mount {
        volume      = "master"
        destination = "/data"
      }

      env {
        WEED_MASTER_VOLUME_GROWTH_COPY_1 = "2"
      }

      config {
        image = "chrislusf/seaweedfs:${var.versions.seaweedfs}"

        ports = [
          "http",
          "grpc",
          "metrics",
        ]

        args = [
          "-v=${var.log_level}",
          "master",
          "-mdir=/data",
          "-defaultReplication=010",
          "-volumeSizeLimitMB=5120",
          "-peers=10.1.10.10:9333,10.1.10.20:9333,10.1.10.40:9333",

          "-ip=${NOMAD_IP_http}",
          "-ip.bind=0.0.0.0",
          "-port=${NOMAD_PORT_http}",
          "-port.grpc=${NOMAD_PORT_grpc}",
          "-metricsPort=${NOMAD_PORT_metrics}",

          "-raftHashicorp",
          "-resumeState",
        ]
      }

      resources {
        cpu        = 300
        memory     = 128
        memory_max = 256
      }

      service {
        name = "seaweedfs-master"
        port = "http"

        tags = [
          meta.seaweedfs_index,

          "traefik.enable=true",
          "traefik.http.routers.seaweedfs-master.entrypoints=https",
          "traefik.http.routers.seaweedfs-master.rule=Host(`seaweedfs-master.service.consul`)",
        ]

        meta {
          alloc_id  = NOMAD_ALLOC_ID
          component = "master"
          metrics   = NOMAD_ADDR_metrics
        }

        check {
          name     = "SeaweedFS master"
          type     = "tcp"
          port     = "http"
          interval = "20s"
          timeout  = "1s"

          initial_status = "passing"
        }
      }
    }
  }

  group "volume" {
    count = 2

    update {
      max_parallel = 1
      stagger      = "2m"
    }

    migrate {
      min_healthy_time = "2m"
    }

    network {
      port "http" {
        to     = 9433
        static = 9433
      }
      port "grpc" {
        to     = 19433
        static = 19433
      }
      port "metrics" {}
    }

    volume "index" {
      type   = "host"
      source = "seaweedfs-index"
    }

    volume "ssd" {
      type   = "host"
      source = "seaweedfs-ssd"
    }

    task "volume" {
      driver = "docker"
      user   = "nobody"

      kill_signal  = "SIGINT"
      kill_timeout = "90s"

      volume_mount {
        volume      = "index"
        destination = "/data/index"
      }

      volume_mount {
        volume      = "ssd"
        destination = "/data/ssd"
      }

      config {
        image = "chrislusf/seaweedfs:${var.versions.seaweedfs}"

        ports = [
          "http",
          "grpc",
          "metrics",
        ]

        args = [
          "-v=${var.log_level}",
          "volume",
          "-dir=/data/ssd",
          "-disk=ssd",
          "-max=25",
          "-dir.idx=/data/index",

          "-dataCenter=${node.datacenter}",
          "-rack=${node.unique.name}",
          "-publicUrl=${NOMAD_ADDR_http}",

          "-mserver=1.seaweedfs-master.service.consul:9333,3.seaweedfs-master.service.consul:9333,3.seaweedfs-master.service.consul:9333",

          "-ip=${NOMAD_IP_http}",
          "-ip.bind=0.0.0.0",
          "-port=${NOMAD_PORT_http}",
          "-port.grpc=${NOMAD_PORT_grpc}",
          "-metricsPort=${NOMAD_PORT_metrics}",
        ]
      }

      resources {
        cpu        = 512
        memory     = 2048
        memory_max = 4096
      }

      service {
        name = "seaweedfs-volume"
        port = "http"

        meta {
          alloc_id  = NOMAD_ALLOC_ID
          component = "volume"
          metrics   = NOMAD_ADDR_metrics
        }

        check {
          name     = "SeaweedFS volume"
          type     = "http"
          protocol = "http"
          port     = "http"
          path     = "/healthz"
          interval = "20s"
          timeout  = "1s"
        }
      }
    }
  }

  group "filer" {
    count = 2

    update {
      max_parallel = 1
      stagger      = "2m"
    }

    migrate {
      min_healthy_time = "2m"
    }

    network {
      port "http" {
        to     = 9533
        static = 9533
      }
      port "grpc" {
        to     = 19533
        static = 19533
      }
      port "metrics" {}
    }

    task "filer" {
      driver = "docker"
      user   = "nobody"

      vault {
        policies = ["seaweedfs"]
      }

      kill_signal  = "SIGINT"
      kill_timeout = "90s"

      config {
        image = "chrislusf/seaweedfs:${var.versions.seaweedfs}"

        ports = [
          "http",
          "grpc",
          "metrics",
        ]

        args = [
          "-v=${var.log_level}",
          "filer",
          "-master=1.seaweedfs-master.service.consul:9333,3.seaweedfs-master.service.consul:9333,3.seaweedfs-master.service.consul:9333",

          "-s3=false",
          "-webdav=false",

          "-dataCenter=${node.datacenter}",
          "-rack=${node.unique.name}",

          "-ip=${NOMAD_IP_http}",
          "-ip.bind=0.0.0.0",
          "-port=${NOMAD_PORT_http}",
          "-port.grpc=${NOMAD_PORT_grpc}",
          "-metricsPort=${NOMAD_PORT_metrics}",
        ]

        volumes = [
          "local/filer.toml:/etc/seaweedfs/filer.toml:ro"
        ]
      }

      template {
        data        = file("filer.toml")
        destination = "local/filer.toml"
      }

      template {
        data = <<-EOH
        {{ with secret "postgres/creds/seaweedfs" }}
        WEED_POSTGRES2_USERNAME='{{ .Data.username }}'
        WEED_POSTGRES2_PASSWORD='{{ .Data.password }}'
        {{- end }}
        EOH

        destination = "secrets/db.env"
        env         = true
      }

      resources {
        cpu        = 500
        memory     = 256
        memory_max = 512
      }

      service {
        name = "seaweedfs-filer"
        port = "http"

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.seaweedfs-filer.entrypoints=https",
          "traefik.http.routers.seaweedfs-filer.rule=Host(`seaweedfs-filer.service.consul`)",
        ]

        meta {
          alloc_id  = NOMAD_ALLOC_ID
          component = "filer"
          metrics   = NOMAD_ADDR_metrics
        }

        check {
          name     = "SeaweedFS filer"
          type     = "tcp"
          port     = "http"
          interval = "20s"
          timeout  = "1s"
        }
      }
    }
  }
}
