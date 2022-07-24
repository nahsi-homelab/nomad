variables {
  versions = {
    mimir = "2.2.0"
  }
}

locals {
  certs = {
    "CA"   = "issuing_ca",
    "cert" = "certificate",
    "key"  = "private_key",
  }
}

job "mimir" {
  datacenters = [
    "syria",
  ]
  namespace = "observability"

  vault {
    policies = ["mimir"]
  }

  group "compactor" {
    count = 1

    ephemeral_disk {
      size    = 1000
      migrate = true
      sticky  = true
    }

    network {
      port "http" {}
      port "grpc" {}
    }

    service {
      name = "mimir-compactor"
      port = "http"

      meta {
        alloc_id  = NOMAD_ALLOC_ID
        component = "compactor"
      }

      tags = [
        "traefik.enable=true",
        "traefik.consulcatalog.connect=true",
        "traefik.http.routers.mimir-compactor-ring.entrypoints=https",
        "traefik.http.routers.mimir-compactor-ring.rule=Host(`mimir-compactor.service.consul`) && Path(`/compactor/ring`)",
      ]

      check {
        name            = "Mimir compactor"
        port            = "http"
        protocol        = "https"
        tls_skip_verify = true
        type            = "http"
        path            = "/ready"
        interval        = "20s"
        timeout         = "1s"
      }
    }

    task "compactor" {
      driver       = "docker"
      user         = "nobody"
      kill_timeout = "90s"

      config {
        image = "grafana/mimir:${var.versions.mimir}"
        ports = [
          "http",
          "grpc",
        ]

        args = [
          "-target=compactor",
          "-config.file=/local/config.yml",
          "-config.expand-env=true",
        ]
      }

      template {
        data        = file("config.yml")
        destination = "local/config.yml"
      }

      template {
        data = <<-EOH
        {{ with secret "secret/minio/mimir" }}
        S3_ACCESS_KEY_ID={{ .Data.data.access_key }}
        S3_SECRET_ACCESS_KEY={{ .Data.data.secret_key }}
        {{- end }}
        EOH

        destination = "secrets/s3.env"
        env         = true
      }

      dynamic "template" {
        for_each = local.certs
        content {
          data = <<-EOH
          {{- with secret "pki/issue/internal" "ttl=10d" "common_name=mimir-compactor.service.consul" (env "attr.unique.network.ip-address" | printf "ip_sans=%s") -}}
          {{ .Data.${template.value} }}
          {{- end -}}
          EOH

          destination = "secrets/certs/${template.key}.pem"
          change_mode = "restart"
          splay       = "10m"
        }
      }

      resources {
        cpu        = 3000
        memory     = 256
        memory_max = 1024
      }
    }
  }

  group "ruler" {
    count = 1

    constraint {
      distinct_property = node.unique.name
    }

    ephemeral_disk {
      migrate = true
      sticky  = true
    }

    network {
      port "http" {}
      port "grpc" {}
    }

    service {
      name = "mimir-ruler"
      port = "http"

      meta {
        alloc_id  = NOMAD_ALLOC_ID
        component = "ruler"
      }

      tags = [
        "traefik.enable=true",
        "traefik.consulcatalog.connect=true",

        "traefik.http.routers.mimir-ruler.entrypoints=https",
        "traefik.http.routers.mimir-ruler.rule=Host(`mimir-query-frontend.service.consul`) && (PathPrefix(`/mimir/api/v1/rules`) || PathPrefix(`/api/prom/rules`) || PathPrefix (`/prometheus/api/v1`))",

        "traefik.http.routers.mimir-ruler-ring.entrypoints=https",
        "traefik.http.routers.mimir-ruler-ring.rule=Host(`mimir-ruler.service.consul`) && Path(`/ruler/ring`)",
      ]

      check {
        name            = "Mimir ruler"
        port            = "http"
        protocol        = "https"
        tls_skip_verify = true
        type            = "http"
        path            = "/ready"
        interval        = "20s"
        timeout         = "1s"
      }
    }

    task "ruler" {
      driver       = "docker"
      user         = "nobody"
      kill_timeout = "90s"

      config {
        image = "grafana/mimir:${var.versions.mimir}"
        ports = [
          "http",
          "grpc",
        ]

        args = [
          "-target=ruler",
          "-config.file=/local/config.yml",
          "-config.expand-env=true",
        ]
      }

      template {
        data        = file("config.yml")
        destination = "local/config.yml"
      }

      dynamic "template" {
        for_each = fileset(".", "rules/**")

        content {
          data            = file(template.value)
          destination     = "local/${template.value}"
          left_delimiter  = "[["
          right_delimiter = "]]"
        }
      }

      template {
        data = <<-EOH
        {{ with secret "secret/minio/mimir" }}
        S3_ACCESS_KEY_ID={{ .Data.data.access_key }}
        S3_SECRET_ACCESS_KEY={{ .Data.data.secret_key }}
        {{- end }}
        EOH

        destination = "secrets/s3.env"
        env         = true
      }

      dynamic "template" {
        for_each = local.certs
        content {
          data = <<-EOH
          {{- with secret "pki/issue/internal" "ttl=10d" "common_name=mimir-ruler.service.consul" (env "attr.unique.network.ip-address" | printf "ip_sans=%s") -}}
          {{ .Data.${template.value} }}
          {{- end -}}
          EOH

          destination = "secrets/certs/${template.key}.pem"
          change_mode = "restart"
          splay       = "10m"
        }
      }

      resources {
        cpu        = 1000
        memory     = 256
        memory_max = 512
      }
    }
  }

  group "distibutor" {
    count = 2

    constraint {
      distinct_property = node.unique.name
    }

    network {
      port "http" {}
      port "grpc" {}
    }

    service {
      name = "mimir-distributor"
      port = "http"

      meta {
        alloc_id  = NOMAD_ALLOC_ID
        component = "distributor"
      }

      tags = [
        "traefik.enable=true",
        "traefik.consulcatalog.connect=true",

        "traefik.http.routers.mimir-distributor.entrypoints=https",
        "traefik.http.routers.mimir-distributor.rule=Host(`mimir-distributor.service.consul`)",
        "traefik.http.middlewares.mimir-distributor.basicauth.users=promtail:$$apr1$$wnir40yf$$vcxJYiqcEQLknQAZcpy/I1",
        "traefik.http.routers.mimir-distirbutor.middlewares=mimir-distributor@consulcatalog",

        "traefik.http.routers.mimir-distributor-ring.entrypoints=https",
        "traefik.http.routers.mimir-distributor-ring.rule=Host(`mimir-distributor.cinarra.com`) && Path(`/distributor/ring`)",
      ]

      check {
        name            = "Mimir distibutor"
        port            = "http"
        protocol        = "https"
        tls_skip_verify = true
        type            = "http"
        path            = "/ready"
        interval        = "20s"
        timeout         = "1s"
      }
    }

    task "distibutor" {
      driver       = "docker"
      user         = "nobody"
      kill_timeout = "90s"

      config {
        image = "grafana/mimir:${var.versions.mimir}"
        ports = [
          "http",
          "grpc",
        ]

        args = [
          "-target=distributor",
          "-config.file=/local/config.yml",
          "-config.expand-env=true",
        ]
      }

      template {
        data        = file("config.yml")
        destination = "local/config.yml"
      }

      dynamic "template" {
        for_each = local.certs
        content {
          data = <<-EOH
          {{- with secret "pki/issue/internal" "ttl=10d" "common_name=mimir-distributer.service.consul" (env "attr.unique.network.ip-address" | printf "ip_sans=%s") -}}
          {{ .Data.${template.value} }}
          {{- end -}}
          EOH

          destination = "secrets/certs/${template.key}.pem"
          change_mode = "restart"
          splay       = "10m"
        }
      }

      resources {
        cpu        = 200
        memory     = 128
        memory_max = 1024
      }
    }
  }

  group "ingester" {
    count = 2

    constraint {
      distinct_property = node.unique.name
    }

    ephemeral_disk {
      size    = 4000
      migrate = true
      sticky  = true
    }

    network {
      port "http" {}
      port "grpc" {}
    }

    service {
      name = "mimir-ingester"
      port = "http"

      meta {
        alloc_id  = NOMAD_ALLOC_ID
        component = "ingester"
      }

      tags = [
        "traefik.enable=true",
        "traefik.consulcatalog.connect=true",
        "traefik.http.routers.mimir-ingester-ring.entrypoints=https",
        "traefik.http.routers.mimir-ingester-ring.rule=Host(`mimir-ingester.service.consul`) && Path(`/ring`)",
      ]

      check {
        name            = "Mimir ingester"
        port            = "http"
        protocol        = "https"
        tls_skip_verify = true
        type            = "http"
        path            = "/ready"
        interval        = "20s"
        timeout         = "1s"
      }
    }

    task "ingester" {
      driver       = "docker"
      user         = "nobody"
      kill_timeout = "90s"

      config {
        image = "grafana/mimir:${var.versions.mimir}"
        ports = [
          "http",
          "grpc",
        ]

        args = [
          "-target=ingester",
          "-config.file=/local/config.yml",
          "-config.expand-env=true",
        ]
      }

      template {
        data        = file("config.yml")
        destination = "local/config.yml"
      }

      template {
        data = <<-EOH
        {{ with secret "secret/minio/mimir" }}
        S3_ACCESS_KEY_ID={{ .Data.data.access_key }}
        S3_SECRET_ACCESS_KEY={{ .Data.data.secret_key }}
        {{- end }}
        EOH

        destination = "secrets/s3.env"
        env         = true
      }

      dynamic "template" {
        for_each = local.certs
        content {
          data = <<-EOH
          {{- with secret "pki/issue/internal" "ttl=10d" "common_name=mimir-ingestor.service.consul" (env "attr.unique.network.ip-address" | printf "ip_sans=%s") -}}
          {{ .Data.${template.value} }}
          {{- end -}}
          EOH

          destination = "secrets/certs/${template.key}.pem"
          change_mode = "restart"
          splay       = "10m"
        }
      }

      resources {
        cpu        = 300
        memory     = 128
        memory_max = 2048
      }
    }
  }

  group "querier" {
    count = 2

    constraint {
      distinct_property = node.unique.name
    }

    network {
      port "http" {}
      port "grpc" {}
    }

    service {
      name = "mimir-querier"
      port = "http"

      meta {
        alloc_id  = NOMAD_ALLOC_ID
        component = "querier"
      }

      check {
        name            = "Mimir querier"
        port            = "http"
        protocol        = "https"
        tls_skip_verify = true
        type            = "http"
        path            = "/ready"
        interval        = "20s"
        timeout         = "1s"
      }
    }

    task "querier" {
      driver       = "docker"
      user         = "nobody"
      kill_timeout = "90s"

      config {
        image = "grafana/mimir:${var.versions.mimir}"
        ports = [
          "http",
          "grpc",
        ]

        args = [
          "-target=querier",
          "-config.file=/local/config.yml",
          "-config.expand-env=true",
        ]
      }

      template {
        data        = file("config.yml")
        destination = "local/config.yml"
      }

      template {
        data = <<-EOH
        {{ with secret "secret/minio/mimir" }}
        S3_ACCESS_KEY_ID={{ .Data.data.access_key }}
        S3_SECRET_ACCESS_KEY={{ .Data.data.secret_key }}
        {{- end }}
        EOH

        destination = "secrets/s3.env"
        env         = true
      }

      dynamic "template" {
        for_each = local.certs
        content {
          data = <<-EOH
          {{- with secret "pki/issue/internal" "ttl=10d" "common_name=mimir-querier.service.consul" (env "attr.unique.network.ip-address" | printf  "ip_sans=%s") -}}
          {{ .Data.${template.value} }}
          {{- end -}}
          EOH

          destination = "secrets/certs/${template.key}.pem"
          change_mode = "restart"
          splay       = "10m"
        }
      }

      resources {
        cpu        = 200
        memory     = 128
        memory_max = 2048
      }
    }
  }

  group "query-scheduler" {
    count = 2

    network {
      port "http" {}
      port "grpc" {
        to     = 8096
        static = 8096
      }
    }

    service {
      name = "mimir-query-scheduler"
      port = "http"

      meta {
        alloc_id  = NOMAD_ALLOC_ID
        component = "query-scheduler"
      }

      check {
        name            = "Mimir query-scheduler"
        port            = "http"
        protocol        = "https"
        tls_skip_verify = true
        type            = "http"
        path            = "/ready"
        interval        = "20s"
        timeout         = "1s"
      }
    }

    task "query-scheduler" {
      driver       = "docker"
      user         = "nobody"
      kill_timeout = "90s"

      config {
        image = "grafana/mimir:${var.versions.mimir}"
        ports = [
          "http",
          "grpc",
        ]

        args = [
          "-target=query-scheduler",
          "-config.file=/local/config.yml",
          "-config.expand-env=true",
        ]
      }

      template {
        data        = file("config.yml")
        destination = "local/config.yml"
      }

      dynamic "template" {
        for_each = local.certs
        content {
          data = <<-EOH
          {{- with secret "pki/issue/internal" "ttl=10d" "common_name=mimir-query-scheduler.service.consul" (env "attr.unique.network.ip-address" | printf  "ip_sans=%s") -}}
          {{ .Data.${template.value} }}
          {{- end -}}
          EOH

          destination = "secrets/certs/${template.key}.pem"
          change_mode = "restart"
          splay       = "10m"
        }
      }

      resources {
        cpu        = 100
        memory     = 64
        memory_max = 128
      }
    }
  }

  group "query-frontend" {
    count = 2

    network {
      port "http" {}
      port "grpc" {}
    }

    service {
      name = "mimir-query-frontend"
      port = "http"

      meta {
        alloc_id  = NOMAD_ALLOC_ID
        component = "query-frontend"
      }

      tags = [
        "traefik.enable=true",
        "traefik.consulcatalog.connect=true",

        "traefik.http.routers.mimir-query-frontend.entrypoints=https",
        "traefik.http.routers.mimir-query-frontend.rule=Host(`mimir-query-frontend.service.consul`)",
        "traefik.http.middlewares.mimir-query-frontend.basicauth.users=grafana:$apr1$5yBhGAwc$SrXPFIfimv5cCNH8UrDpE/",
        "traefik.http.routers.mimir-query-frontend.middlewares=mimir-query-frontend@consulcatalog",
      ]

      check {
        name            = "Mimir query-frontend"
        port            = "http"
        protocol        = "https"
        tls_skip_verify = true
        type            = "http"
        path            = "/ready"
        interval        = "20s"
        timeout         = "1s"
      }
    }

    task "query-frontend" {
      driver       = "docker"
      user         = "nobody"
      kill_timeout = "90s"

      config {
        image = "grafana/mimir:${var.versions.mimir}"
        ports = [
          "http",
          "grpc",
        ]

        args = [
          "-target=query-frontend",
          "-config.file=/local/config.yml",
          "-config.expand-env=true",
        ]
      }

      template {
        data        = file("config.yml")
        destination = "local/config.yml"
      }

      dynamic "template" {
        for_each = local.certs
        content {
          data = <<-EOH
          {{- with secret "pki/issue/internal" "ttl=10d" "common_name=mimir-query-frontend.service.consul" (env "attr.unique.network.ip-address" | printf  "ip_sans=%s") -}}
          {{ .Data.${template.value} }}
          {{- end -}}
          EOH

          destination = "secrets/certs/${template.key}.pem"
          change_mode = "restart"
          splay       = "10m"
        }
      }

      resources {
        cpu        = 100
        memory     = 64
        memory_max = 128
      }
    }
  }

  group "store-gateway" {
    count = 1

    constraint {
      distinct_property = node.unique.name
    }

    ephemeral_disk {
      size    = 1000
      migrate = true
      sticky  = true
    }

    network {
      port "http" {}
      port "grpc" {}
    }

    service {
      name = "mimir-store-gateway"
      port = "http"

      meta {
        alloc_id  = NOMAD_ALLOC_ID
        component = "store-gateway"
      }

      check {
        name            = "Mimir store-gateway"
        port            = "http"
        protocol        = "https"
        tls_skip_verify = true
        type            = "http"
        path            = "/ready"
        interval        = "20s"
        timeout         = "1s"
      }
    }

    task "store-gateway" {
      driver       = "docker"
      user         = "nobody"
      kill_timeout = "90s"

      config {
        image = "grafana/mimir:${var.versions.mimir}"
        ports = [
          "http",
          "grpc",
        ]

        args = [
          "-target=store-gateway",
          "-config.file=/local/config.yml",
          "-config.expand-env=true",
        ]
      }

      template {
        data        = file("config.yml")
        destination = "local/config.yml"
      }

      template {
        data = <<-EOH
        {{ with secret "secret/minio/mimir" }}
        S3_ACCESS_KEY_ID={{ .Data.data.access_key }}
        S3_SECRET_ACCESS_KEY={{ .Data.data.secret_key }}
        {{- end }}
        EOH

        destination = "secrets/s3.env"
        env         = true
      }

      dynamic "template" {
        for_each = local.certs
        content {
          data = <<-EOH
          {{- with secret "pki/issue/internal" "ttl=10d" "common_name=mimir-store-gateway.service.consul" (env "attr.unique.network.ip-address" | printf "ip_sans=%s") -}}
          {{ .Data.${template.value} }}
          {{- end -}}
          EOH

          destination = "secrets/certs/${template.key}.pem"
          change_mode = "restart"
          splay       = "10m"
        }
      }

      resources {
        cpu        = 200
        memory     = 128
        memory_max = 1024
      }
    }
  }
}
