output "zones" {
  description = "Map of zone id -> zone id, for all zone types (simple, vlan, qinq, vxlan, evpn)."
  value = merge(
    { for k, v in proxmox_sdn_zone_simple.this : k => v.id },
    { for k, v in proxmox_sdn_zone_vlan.this : k => v.id },
    { for k, v in proxmox_sdn_zone_qinq.this : k => v.id },
    { for k, v in proxmox_sdn_zone_vxlan.this : k => v.id },
    { for k, v in proxmox_sdn_zone_evpn.this : k => v.id },
  )
}

output "zone_details" {
  description = "Full zone resources per type (id, state, pending)."
  value = {
    simple = proxmox_sdn_zone_simple.this
    vlan   = proxmox_sdn_zone_vlan.this
    qinq   = proxmox_sdn_zone_qinq.this
    vxlan  = proxmox_sdn_zone_vxlan.this
    evpn   = proxmox_sdn_zone_evpn.this
  }
}

output "zones_config" {
  description = "Fingerprint of the zone definitions (used by the networking module to trigger an SDN re-apply on zone changes)."
  value       = jsonencode(var.zones)
}
