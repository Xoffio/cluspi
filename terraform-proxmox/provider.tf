# Specify required Terraform and provider versions
terraform {
  required_version = ">= 1.0.0" # Minimum version of Terraform CLI required
  required_providers {
    http = {
      source  = "hashicorp/http"
      version = "3.5.0"
    }
    proxmox = {
      source  = "telmate/proxmox" # Use the Telmate Proxmox provider
      version = "3.0.2-rc01"
    }
  }
}

# Configure the Proxmox provider with API credentials and connection settings
provider "proxmox" {
  pm_api_url          = var.pm_api_url
  pm_api_token_id     = var.pm_api_token_id
  pm_api_token_secret = var.pm_api_token_secret
  pm_tls_insecure     = true
}

data "http" "github_keys" {
  url = "https://github.com/${var.github_user}.keys"
}
