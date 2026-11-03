resource "proxmox_sdn_vnet" "this" {
  for_each = var.vnets

  id            = each.key
  zone          = each.value.zone
  vlan_aware    = each.value.vlan_aware
  alias         = each.value.alias
  isolate_ports = each.value.isolate_ports
  tag           = each.value.tag
}
