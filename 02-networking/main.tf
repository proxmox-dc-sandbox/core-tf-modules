# ---------------------------------------------------------------------------
# NETWORKING: the logical overlay.
#   - VNets (sdn-vnet module), attached to zones created by the foundation module
#   - Subnets attached to the vnets
#   - Application of the SDN configuration (proxmox_sdn_applier)
#
# Upstream values (zones, fingerprints) are passed in by the caller. This
# module does not read any remote state and has no backend/provider config.
# ---------------------------------------------------------------------------

module "vnets" {
  source = "../modules/sdn-vnet"
  vnets  = var.sdn_vnets
}

# NOTE: two resources instead of one because of a provider 0.116.0 bug:
# an object (dhcp_range) read straight from a for_each value is seen as
# "unknown" and rejected ("Received unknown value ... cannot handle unknown
# values"). Rebuilding the object field-by-field fixes it, but only when the
# expression is unconditional — a ternary (null branch) triggers the bug too.
resource "proxmox_sdn_subnet" "subnets" {
  for_each = { for k, v in var.sdn_subnets : k => v if v.dhcp_range == null }

  vnet            = module.vnets.vnets[each.value.vnet]
  cidr            = each.value.cidr
  gateway         = each.value.gateway
  snat            = each.value.snat
  dhcp_dns_server = each.value.dhcp_dns_server
  dns_zone_prefix = each.value.dns_zone_prefix
}

resource "proxmox_sdn_subnet" "subnets_dhcp" {
  for_each = { for k, v in var.sdn_subnets : k => v if v.dhcp_range != null }

  vnet            = module.vnets.vnets[each.value.vnet]
  cidr            = each.value.cidr
  gateway         = each.value.gateway
  snat            = each.value.snat
  dhcp_dns_server = each.value.dhcp_dns_server
  dhcp_range = {
    start_address = each.value.dhcp_range.start_address
    end_address   = each.value.dhcp_range.end_address
  }
  dns_zone_prefix = each.value.dns_zone_prefix
}

# Triggers a re-apply of the SDN configuration whenever zones, vnets or
# subnets change (the applier resource only runs on create/destroy).
resource "null_resource" "sdn_trigger" {
  triggers = {
    zones       = var.zones_config
    controllers = var.controllers_config
    vnets       = jsonencode(var.sdn_vnets)
    subnets     = jsonencode(var.sdn_subnets)
  }
}

# Forces the application of the SDN configuration (zones + vnets + subnets) on the cluster.
resource "proxmox_sdn_applier" "network_apply" {
  depends_on = [
    module.vnets,
    proxmox_sdn_subnet.subnets,
    proxmox_sdn_subnet.subnets_dhcp,
  ]

  lifecycle {
    replace_triggered_by = [null_resource.sdn_trigger]
  }
}
