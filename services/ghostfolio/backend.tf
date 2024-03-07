terraform {
  backend "consul" {
    address = "consul.service.consul:8500"
    scheme  = "http"
    path    = "terraform/nomad/services/ghostfolio"
  }

  required_providers {
    postgresql = {
      source = "cyrilgdn/postgresql"
    }

    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 3.0"
    }
  }
}

provider "nomad" {
  address = "http://nomad.service.consul:4646"
}

provider "vault" {
  address = "http://vault.service.consul:8200"
}

provider "cloudflare" {}

data "cloudflare_zone" "nahsi" {
  name = "nahsi.dev"
}
