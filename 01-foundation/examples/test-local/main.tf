# ---------------------------------------------------------------------------
# Local development example: calls the parent foundation module.
#
# Run from this directory:
#   cp terraform.tfvars.example terraform.tfvars
#   tofu init
#   tofu plan
#
# State stays local (backend.tf) and never leaks into the module sources.
# ---------------------------------------------------------------------------

locals {
  linux_bridges = {
    "vmbr1" = {
      node_name = "pve"
      address   = "10.69.11.1/24"
      comment   = "Management Network"
    }
  }

  sdn_zones = {
    "DMZ" = {
      type  = "simple"
      nodes = ["pve"]
      mtu   = 1500
      dhcp  = "dnsmasq"
      ipam  = "pve"
    }
    "LAB" = {
      type  = "simple"
      nodes = ["pve"]
      mtu   = 1500
    }
  }

  sdn_controllers = {
    "frr1" = {
      asn   = 64512
      peers = ["10.69.0.1"]
    }
  }

  storage_roles = {
    "iso"    = { content = ["iso"] }
    "vztmpl" = { content = ["vztmpl"] }
  }

  os_images = {
    "ubuntu-2404-cloudinit" = {
      node      = "pve"
      datastore = "iso"
      url       = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
      file_name = "noble-server-cloudimg-amd64.img"
    }
  }

  lxc_templates = {
    "alpine-3-20" = {
      node      = "pve"
      datastore = "vztmpl"
      url       = "http://download.proxmox.com/images/system/alpine-3.20-default_20240605_amd64.tar.xz"
      file_name = "alpine-3.20-default_20240605_amd64.tar.xz"
    }
  }
}

module "foundation" {
  source = "../.."

  linux_bridges   = local.linux_bridges
  sdn_zones       = local.sdn_zones
  sdn_controllers = local.sdn_controllers
  storage_roles   = local.storage_roles
  os_images       = local.os_images
  lxc_templates   = local.lxc_templates
}

output "zones" {
  value = module.foundation.zones
}

output "os_images" {
  value = module.foundation.os_images
}
