job "homer" {

  datacenters = ["syria", "asia"]
  type        = "service"

  update {
    max_parallel = 1
    stagger      = "10s"
    auto_revert  = true
  }

  constraint {
    operator = "distinct_hosts"
    value    = "true"
  }

  group "homer" {
    count = 2

    network {
      port "http" {
        to = 8080
      }
    }

    service {
      name = "homer"
      port = "http"
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.homer.rule=Host(`homer.service.consul`)",
        "traefik.http.routers.homer.tls=true"
      ]
    }

    task "homer" {
      driver = "docker"

      config {
        image = "b4bz/homer:21.09.2-amd64"

        ports = [
          "http"
        ]

        volumes = [
          "local/config.yml:/www/assets/config.yml"
        ]
      }

      template {
        destination = "local/config.yml"
        data        = <<EOH
---
title: "Dashboard"
subtitle: "Homelab"
columns: "auto"
connectivityCheck: false

links:
  - name: "Homelab"
    icon: "fab fa-github"
    url: "https://github.com/nahsi-homelab"

services:
  - name: "Applications"
    icon: "fas fa-code-branch"
    items:
      - name: "Jellyfin"
        icon: "fas fa-film"
        url: "https://jellyfin.service.consul"
      - name: "Audioserve"
        icon: "fas fa-book"
        url: "https://audioserve.service.consul"
      - name: "Polaris"
        icon: "fas fa-music"
        url: "https://polaris.service.consul"
      - name: "Linkding"
        icon: "fas fa-link"
        url: "https://links.service.consul"
      - name: "Podgrab"
        icon: "fas fa-podcast"
        url: "https://podgrab.service.consul"
      - name: "Transmission"
        icon: "fas fa-download"
        url: "https://transmission.service.consul"
      - name: "LLPSI"
        url: "https://llpsi.service.consul"

  - name: "Operations"
    icon: "fas fa-server"
    items:
      - name: "Unifi"
        url: "https://unifi.service.consul"
      - name: "Grafana"
        url: "https://grafana.service.consul"
      - name: "Prometheus"
        url: "https://prometheus.service.consul"
      - name: "Traefik"
        url: "https://traefik-internal.service.consul"
      - name: "SFTPGO"
        url: "https://sftpgo.service.consul"
      - name: "minio"
        url: "https://minio.nahsi.dev"

  - name: "HashiStack"
    icon: "fas fa-cloud"
    items:
      - name: "Nomad"
        url: "http://nomad.service.consul:4646"
      - name: "Consul"
        url: "http://consul.service.consul:8500"
      - name: "Vault"
        url: "http://vault.service.consul:8200"
EOH
      }

      resources {
        memory = 64
      }
    }
  }
}
