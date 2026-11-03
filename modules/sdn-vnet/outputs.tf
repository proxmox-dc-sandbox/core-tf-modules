output "vnets" {
  description = "Map of vnet id -> vnet id (usable as bridge name in VM network devices)."
  value       = { for k, v in proxmox_sdn_vnet.this : k => v.id }
}

output "vnet_details" {
  description = "Full vnet resources map."
  value       = proxmox_sdn_vnet.this
}
