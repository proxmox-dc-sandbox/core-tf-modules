terraform {
  required_version = ">= 1.8.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.70.0"
    }
  }
}

# Local provider configuration for module development only.
# In a client project, Terragrunt generates this block from root.hcl.
provider "proxmox" {
  insecure  = var.proxmox_insecure
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token

  ssh {
    agent               = var.proxmox_ssh_agent
    username            = var.proxmox_ssh_username
    private_key         = try(file(var.proxmox_ssh_private_key), null)
    node_address_source = var.proxmox_ssh_node_address_source
    socks5_server       = var.proxmox_ssh_socks5_server
    socks5_username     = var.proxmox_ssh_socks5_username
    socks5_password     = var.proxmox_ssh_socks5_password

    node {
      name    = var.proxmox_ssh_node_name
      address = var.proxmox_ssh_address
    }
  }
}
