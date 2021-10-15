variables {
  versions = {
    traefik = "2.5.3"
    promtail = "2.3.0"
  }
}

job "ingress" {
  datacenters = ["syria"]
  type        = "service"

  update {
    max_parallel = 1
    stagger      = "1m"
    auto_revert  = true
  }

  group "traefik" {
    network {
      port "traefik" {
        to = 8080
      }

      port "http" {
        static = 80
        to = 80
        host_network = "public"
      }

      port "https" {
        static = 443
        to = 443
        host_network = "public"
      }

      port "promtail" {
        to = 3000
      }
    }

    service {
      name = "ingress"
      port = "traefik"

      check {
        type = "http"
        protocol = "http"
        path = "/ping"
        port = "traefik"
        interval = "20s"
        timeout = "2s"
      }
    }

    task "traefik" {
      driver = "docker"

      kill_timeout = "30s"

      vault {
        policies = ["public-cert"]
      }

      config {
        image = "traefik:${var.versions.traefik}"

        extra_hosts = [
          "host.docker.internal:host-gateway"
        ]

        ports = [
          "traefik",
          "http",
          "https"
        ]

        args = [
          "--configFile=local/config.yml"
        ]
      }

      template {
        data = <<EOH
entryPoints:
  http:
    address: ":80"
    transport:
      lifeCycle:
        requestAcceptGraceTimeout: 15
        graceTimeOut: 10
    http:
      redirections:
        entryPoint:
          to: https
          scheme: https

  https:
    address: ":443"
    transport:
      lifeCycle:
        requestAcceptGraceTimeout: 15
        graceTimeOut: 10
    http:
      tls:
        domains:
          - main: "nahsi.dev"
            sans:
              - "*.nahsi.dev"

  traefik:
    address: ":8080"

ping:
  entrypoint: traefik

metrics:
  prometheus:
    entrypoint: traefik

accessLog:
  filePath: "/alloc/data/access.log"
  format: json

providers:
  consulCatalog:
    prefix: "ingress"
    exposedByDefault: false
    endpoint:
      address: "host.docker.internal:8500"
  file:
    filename: "local/traefik/tls.yml"

EOH

        destination = "local/config.yml"
        change_mode = "restart"
        splay       = "1m"
      }

      template {
        data = <<EOH
tls:
  certificates:
    - certFile: "secrets/cert.pem"
      keyFile: "secrets/key.pem"
EOH

        destination = "local/traefik/tls.yml"
        change_mode = "noop"
      }

      template {
        data = <<EOH
{{- with secret "secret/certificate" -}}
{{ .Data.data.ca_bundle }}{{ end }}
EOH

        destination   = "secrets/cert.pem"
        change_mode   = "restart"
        splay         = "1m"
      }

      template {
        data = <<EOH
{{- with secret "secret/certificate" -}}
{{ .Data.data.key }}{{ end }}
EOH

        destination   = "secrets/key.pem"
        change_mode   = "restart"
        splay         = "1m"
      }

      resources {
        cpu = 100
        memory = 128
      }
    }

    task "promtail" {
      driver = "docker"

      lifecycle {
        hook    = "poststart"
        sidecar = true
      }

      service {
        name = "promtail"
        port = "promtail"
        address_mode = "host"

        check {
          type     = "http"
          path     = "/ready"
          interval = "10s"
          timeout  = "2s"
        }
      }

      resources {
        cpu = 50
        memory = 128
      }

      config {
        image = "grafana/promtail:${var.versions.promtail}"

        args = [
          "-config.file",
          "local/config.yaml"
        ]

        ports = [
          "promtail"
        ]
      }

      template {
        data = <<EOH
server:
  http_listen_port: 3000
  grpc_listen_port: 0

positions:
  filename: "local/positions.yml"

client:
  url: http://loki.service.consul:3100/loki/api/v1/push

scrape_configs:
- job_name: traefik
  static_configs:
  - targets:
      - localhost
    labels:
      app: ingress
      __path__: "/alloc/logs/traefik.std*.0"
  pipeline_stages:
    - regex:
        expression: '^time="(?P<time>.*)" level=(?P<level>.*) msg="(?P<msg>.*)"'
    - timestamp:
        source: time
        format: 2006-01-02T15:04:05Z

- job_name: traefik-access
  static_configs:
  - targets:
      - localhost
    labels:
      app: ingress
      type: access-log
      __path__: "/alloc/data/access.log"
  pipeline_stages:
    - json:
        expressions:
          time: time
          level: level
          method: RequestMethod
          status: DownstreamStatus
          path: RequestPath
    - labels:
        method:
        status:
    - drop:
        source: path
        expression: "/ping"
    - drop:
        source: path
        expression: "/metrics"
    - timestamp:
        source: time
        format: 2006-01-02T15:04:05Z
EOH
        destination = "local/config.yaml"
      }
    }
  }
}
