# ---------------------------------------------------------------------------
# Local development example for the networking module.
#
# It reads the local state of the foundation example (sibling module) so the
# whole stack can be developed without Terragrunt:
#   01-foundation/examples/test-local  -> apply first
#   02-networking/examples/test-local  -> this directory
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

locals {
  sdn_vnets = {
    "DMZ" = {
      zone       = "DMZ"
      vlan_aware = false
    }
    "LAB" = {
      zone       = "LAB"
      vlan_aware = false
    }
  }

  sdn_subnets = {
    "DMZ" = {
      vnet            = "DMZ"
      cidr            = "10.69.21.0/24"
      gateway         = "10.69.21.1"
      snat            = false
      dhcp_dns_server = "10.69.21.1"
      dhcp_range = {
        start_address = "10.69.21.100"
        end_address   = "10.69.21.200"
      }
    }
    "LAB" = {
      vnet    = "LAB"
      cidr    = "10.69.51.0/24"
      gateway = "10.69.51.1"
      snat    = false
    }
  }
}

module "networking" {
  source = "../.."

  zones              = data.terraform_remote_state.foundation.outputs.zones
  zones_config       = data.terraform_remote_state.foundation.outputs.zones_config
  controllers_config = data.terraform_remote_state.foundation.outputs.controllers_config

  sdn_vnets   = local.sdn_vnets
  sdn_subnets = local.sdn_subnets
}

output "vnets" {
  value = module.networking.vnets
}

output "subnets" {
  value = module.networking.subnets
}
