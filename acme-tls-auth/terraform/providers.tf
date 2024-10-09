terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "4.4.0"
    }
    tls = {
      source = "hashicorp/tls"
      version = "4.0.6"
    }
  }
}

provider "vault" {
  # Configuration options
  address   = var.vault_server
  namespace = var.vault_ns
}