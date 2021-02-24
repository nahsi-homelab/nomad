# vim: set ft=hcl sw=2 ts=2 :
job "homer" {

  datacenters = ["syria"]

  type        = "service"

  update {
    max_parallel = 1
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
    }

    task "homer" {
      driver = "podman"

      config {
        image = "docker://b4bz/homer:20.12.19-amd64"

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
connectivityCheck: fasle

links:
  - name: "Homelab Github"
    icon: "fab fa-github"
    url: "https://github.com/nahsi-homelab"

services:
  - name: "Applications"
    icon: "fas fa-code-branch"
    items:
      - name: "Jellyfin"
        url: "https://home.service.consul/jellyfin"
      - name: "Polaris"
        url: "http://polaris.service.consul:5050"
      - name: "Audioserve"
        url: "https://home.service.consul/audioserve"
      - name: "Transmission"
        url: "http://transmission.service.consul:9091"

  - name: "Services"
    icon: "fas fa-server"
    items:
      - name: "Unifi"
        url: "https://unifi.service.consul:8443"
      - name: "Nomad"
        url: "https://nomad.service.consul:4646"
      - name: "Consul"
        url: "https://consul.service.consul:8501"
      - name: "Vault"
        url: "https://vault.service.consul:8200"

  - name: "Monitoring"
    icon: "fas fa-cloud"
    items:
      - name: "Grafana"
        url: "https://home.service.consul/grafana"
      - name: "Prometheus"
        url: "https://home.service.consul/prometheus"
EOH
      }
    }
  }
}
