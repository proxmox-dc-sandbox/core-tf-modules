output "zones" {
  description = "SDN zones available for networking module (map: zone id -> zone id)."
  value       = module.zones.zones
}

output "bridges" {
  description = "Linux bridges (map: bridge name -> bridge id)."
  value       = { for k, v in proxmox_network_linux_bridge.bridges : k => v.id }
}

output "os_images" {
  description = "Downloaded OS images (map: image key -> file id, e.g. local:iso/...)."
  value       = { for k, v in proxmox_download_file.os_images : k => v.id }
}

output "lxc_templates" {
  description = "Downloaded LXC templates (map: template key -> file id)."
  value       = { for k, v in proxmox_download_file.lxc_templates : k => v.id }
}

output "datastore_catalog" {
  description = "Datastore capabilities per node (map: node -> datastore id -> content types)."
  value       = module.storage_resolution.datastore_catalog
}

output "storage_roles" {
  description = "Resolved datastore per role per node (map: node -> role -> datastore id)."
  value       = module.storage_resolution.role_datastores
}

output "zones_config" {
  description = "Fingerprint of the zone definitions (used by networking module to trigger an SDN re-apply on zone changes)."
  value       = jsonencode(var.sdn_zones)
}

output "controllers" {
  description = "Created SDN controllers, EVPN and BGP (map: controller id -> controller id)."
  value = merge(
    { for k, v in proxmox_sdn_controller_evpn.controllers : k => v.id },
    { for k, v in proxmox_sdn_controller_bgp.controllers : k => v.id },
  )
}

output "controllers_config" {
  description = "Fingerprint of the SDN controller definitions (used by networking module to trigger an SDN re-apply)."
  value       = jsonencode(var.sdn_controllers)
}
