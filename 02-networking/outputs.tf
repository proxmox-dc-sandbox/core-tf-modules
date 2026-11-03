output "vnets" {
  description = "Map of vnet id -> vnet id (used as bridge name by the compute module)."
  value       = module.vnets.vnets
}

output "subnets" {
  description = "Map of subnet key -> subnet cidr."
  value = merge(
    { for k, v in proxmox_sdn_subnet.subnets : k => v.cidr },
    { for k, v in proxmox_sdn_subnet.subnets_dhcp : k => v.cidr },
  )
}

output "zones" {
  description = "Zones passed through from the foundation module (convenience output)."
  value       = var.zones
}
