include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  # Tag-pinned module source (never use main/master in a client project).
  # Bump `?ref=` explicitly after reviewing the new module version.
  source = "git::https://example.com/org/pdcs-core-tf-modules.git//01-foundation?ref=v1.0.0-rc1"
}

inputs = {
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

    # Plain BGP controller: native module capability (no client-side
    # `generate` workaround needed anymore).
    "chr" = {
      type      = "bgp"
      asn       = 64512
      node_name = "pve"
      peers     = ["10.69.0.254"]
      ebgp      = true
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
