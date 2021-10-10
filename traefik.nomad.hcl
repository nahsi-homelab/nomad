variables {
  versions = {
    traefik = "2.5.3"
    promtail = "2.3.0"
  }
}

job "traefik" {
  datacenters = ["syria", "asia"]
  type        = "system"

  update {
    max_parallel = 1
    stagger      = "1m"
    auto_revert  = true
  }

  group "traefik" {
    network {
      port "traefik" {
        to = 8000
        static = 8000
      }

      port "http" {
        static = 80
        to = 80
      }

      port "https" {
        static = 443
        to = 443
      }

      port "metrics" {}

      port "promtail" {
        to = 3000
      }
    }

    service {
      name = "traefik"
      port = "traefik"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.api.rule=Host(`traefik.service.consul`)",
        "traefik.http.routers.api.service=api@internal"
      ]

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
        policies = ["internal-certs"]
      }

      config {
        image = "traefik:${var.versions.traefik}"

        extra_hosts = [
          "host.docker.internal:host-gateway"
        ]

        ports = [
          "traefik",
          "http",
          "https",
          "metrics"
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
          - main: "service.consul"
            sans:
              - "*.service.consul"

  traefik:
    address: ":8000"

api:
  insecure: true

ping:
  entrypoint: traefik

accessLog:
  filePath: "/alloc/data/access.log"
  format: json

providers:
  consulCatalog:
    prefix: "traefik"
    exposedByDefault: false
    defaultRule: "Host(`{{ .Name }}.service.consul`)"
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

http:
  serversTransports:
    skipverify:
      insecureSkipVerify: true
EOH

        destination = "local/traefik/tls.yml"
        change_mode = "noop"
      }

      template {
        data = <<EOH
{{- with secret "pki/issue/internal" "common_name=*.service.consul" -}}
{{ .Data.certificate }}
{{ .Data.issuing_ca }}{{ end }}
EOH

        destination   = "secrets/cert.pem"
        change_mode   = "restart"
        splay         = "1m"
      }

      template {
        data = <<EOH
{{- with secret "pki/issue/internal" "common_name=*.service.consul" -}}
{{ .Data.private_key }}{{ end }}
EOH

        change_mode   = "restart"
        destination   = "secrets/key.pem"
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
      app: traefik
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
      app: traefik
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
    - timestamp:
        source: time
        format: 2006-01-02T15:04:05Z
EOH
        destination = "local/config.yaml"
      }
    }
  }
}
