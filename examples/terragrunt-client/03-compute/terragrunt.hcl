include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  # Tag-pinned module source (never use main/master in a client project).
  # Bump `?ref=` explicitly after reviewing the new module version.
  source = "git::https://example.com/org/pdcs-core-tf-modules.git//03-compute?ref=v1.0.0-rc1"
}

# Upstream layers: generates the apply order (foundation + networking -> compute).
dependency "foundation" {
  config_path = "../01-foundation"

  mock_outputs = {
    bridges       = { vmbr1 = "vmbr1" }
    os_images     = { "ubuntu-2404-cloudinit" = "local:iso/noble-server-cloudimg-amd64.img" }
    lxc_templates = { "alpine-3-20" = "local:vztmpl/alpine-3.20-default_20240605_amd64.tar.xz" }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

dependency "networking" {
  config_path = "../02-networking"

  mock_outputs = {
    vnets = { DMZ = "DMZ", LAB = "LAB" }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  vnets         = dependency.networking.outputs.vnets
  bridges       = dependency.foundation.outputs.bridges
  os_images     = dependency.foundation.outputs.os_images
  lxc_templates = dependency.foundation.outputs.lxc_templates

  # Cloud-init templates are owned by THIS client project, not by the modules.
  cloud_init_templates_dir = "${get_terragrunt_dir()}/cloud-init-templates"

  extra_bridges = ["vmbr0"]

  storage_roles = {
    "snippets" = { content = ["snippets"] }
    "images"   = { content = ["images"] }
    "rootdir"  = { content = ["rootdir"] }
  }

  virtual_machines = {
    "bastion-01" = {
      target_node = "pve"
      os_image    = "ubuntu-2404-cloudinit"
      cores       = 2
      cpu_type    = "x86-64-v2-AES"
      memory      = 2048
      cloud_init = {
        snippet_datastore = "snippets"
        init_datastore    = "images"
        template_file     = "ubuntu-bastion.yaml.tftpl"
        ssh_keys          = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEXAMPLEEXAMPLEEXAMPLEEXAMPLEEXAMPLEEXAMPLE user@example"]
      }
      interfaces = {
        "net0" = {
          vnet = "DMZ"
          ip   = "10.69.21.5/24"
          gw   = "10.69.21.1"
        }
      }
      disks = {
        "scsi0" = { storage = "images", size = 20 }
      }
    }
  }

  containers = {
    "proxy-nginx-01" = {
      target_node = "pve"
      template    = "alpine-3-20"
      os_type     = "alpine"
      cores       = 1
      memory      = 512
      ssh_keys    = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEXAMPLEEXAMPLEEXAMPLEEXAMPLEEXAMPLEEXAMPLE user@example"]
      interfaces = {
        "eth0" = {
          vnet = "DMZ"
          ip   = "10.69.21.20/24"
          gw   = "10.69.21.1"
        }
      }
      disks = {
        "rootfs" = { storage = "rootdir", size = 10 }
      }
    }
  }
}
