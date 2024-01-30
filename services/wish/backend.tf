terraform {
  backend "consul" {
    address = "consul.service.consul:8500"
    scheme  = "http"
    path    = "terraform/nomad/services/wish"
  }

  required_providers {
    mysql = {
      source = "petoju/mysql"
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

provider "mysql" {
  endpoint = "mariadb.service.consul:3006"
  username = var.mariadb_username
  password = var.mariadb_password
  tls      = true
}

variable "mariadb_username" {
  type      = string
  sensitive = true
}

variable "mariadb_password" {
  type      = string
  sensitive = true
}
