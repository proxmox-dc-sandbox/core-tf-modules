include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  # Tag-pinned module source (never use main/master in a client project).
  # Bump `?ref=` explicitly after reviewing the new module version.
  source = "git::https://example.com/org/pdcs-core-tf-modules.git//02-networking?ref=v1.0.0-rc1"
}

# Upstream layer: generates the apply order (foundation -> networking).
dependency "foundation" {
  config_path = "../01-foundation"

  mock_outputs = {
    zones              = { DMZ = "DMZ", LAB = "LAB" }
    zones_config       = "{}"
    controllers_config = "{}"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  zones              = dependency.foundation.outputs.zones
  zones_config       = dependency.foundation.outputs.zones_config
  controllers_config = dependency.foundation.outputs.controllers_config

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
