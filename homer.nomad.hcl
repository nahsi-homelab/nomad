job "homer" {

  datacenters = ["syria"]
  type        = "service"

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
        data = <<EOH
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
      - name: "Polaris"
        icon: "fas fa-music"
        url: "https://polaris.service.consul"
      - name: "Linkding"
        icon: "fas fa-link"
        url: "https://links.service.consul"
      - name: "Transmission"
        icon: "fas fa-download"
        url: "transmission"

  - name: "Operations"
    icon: "fas fa-server"
    items:
      - name: "Unifi"
        url: "https://unifi.service.consul"
      - name: "Grafana"
        url: "https://home.service.consul/grafana"
      - name: "Prometheus"
        url: "http://prometheus.service.consul:9090"

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
