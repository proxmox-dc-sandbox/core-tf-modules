# ---------------------------------------------------------------------------
# Local development example for the compute module.
#
# It reads the local states of the foundation and networking examples:
#   01-foundation/examples/test-local  -> apply first
#   02-networking/examples/test-local  -> apply second
#   03-compute/examples/test-local     -> this directory
#
# The cloud-init templates live here (client-owned), never in the module.
#
#   cp terraform.tfvars.example terraform.tfvars
#   tofu init && tofu plan
# ---------------------------------------------------------------------------

data "terraform_remote_state" "foundation" {
  backend = "local"

  config = {
    path = "${path.module}/../../../01-foundation/examples/test-local/terraform.tfstate"
  }
}

data "terraform_remote_state" "network" {
  backend = "local"

  config = {
    path = "${path.module}/../../../02-networking/examples/test-local/terraform.tfstate"
  }
}

locals {
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

module "compute" {
  source = "../.."

  vnets         = data.terraform_remote_state.network.outputs.vnets
  bridges       = data.terraform_remote_state.foundation.outputs.bridges
  os_images     = data.terraform_remote_state.foundation.outputs.os_images
  lxc_templates = data.terraform_remote_state.foundation.outputs.lxc_templates

  # Client-owned cloud-init templates.
  cloud_init_templates_dir = "${path.root}/cloud-init-templates"

  extra_bridges    = ["vmbr0"]
  storage_roles    = local.storage_roles
  virtual_machines = local.virtual_machines
  containers       = local.containers
}

output "vm_ids" {
  value = module.compute.vm_ids
}

output "container_ids" {
  value = module.compute.container_ids
}
