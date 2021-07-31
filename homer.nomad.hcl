job "homer" {

  datacenters = ["syria"]
  type        = "service"

  group "homer" {
    count = 1

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
        image = "b4bz/homer:21.07.1-amd64"

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
subtitle: "Syria"
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
        url: "jellyfin"
      - name: "Polaris"
        icon: "fas fa-music"
        url: "https://polaris.service.syria.consul"
      - name: "Audioserve"
        icon: "fas fa-book"
        url: "audioserve"
      - name: "Transmission"
        icon: "fas fa-download"
        url: "transmission"

  - name: "Unifi"
    icon: "fas fa-network-wired"
    items:
      - name: "Syria"
        url: "https://unifi.service.syria.consul"
      - name: "Asia"
        url: "https://unifi.service.asia.consul"

  - name: "Operations"
    icon: "fas fa-server"
    items:
      - name: "Grafana"
        url: "https://home.service.consul/grafana"
      - name: "Prometheus"
        url: "https://home.service.consul/prometheus"

  - name: "HashiStack"
    icon: "fas fa-cloud"
    items:
      - name: "Nomad"
        url: "http://nomad.service.syria.consul:4646"
      - name: "Consul"
        url: "https://consul.service.syria.consul:8501"
      - name: "Vault"
        url: "https://vault.service.syria.consul:8200"
EOH
      }

      resources {
        memory = 64
      }
    }
  }
}
