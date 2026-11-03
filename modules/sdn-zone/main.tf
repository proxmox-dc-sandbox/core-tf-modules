# One resource per zone type; each for_each filters the zones by `type`.
# All resources expose the same id (the zone name), so downstream layers
# only ever see a flat map of zone ids.

resource "proxmox_sdn_zone_simple" "this" {
  for_each = { for k, v in var.zones : k => v if v.type == "simple" }

  id    = each.key
  nodes = each.value.nodes
  mtu   = each.value.mtu

  ipam        = each.value.ipam
  dns         = each.value.dns
  dns_zone    = each.value.dns_zone
  reverse_dns = each.value.reverse_dns
  dhcp        = each.value.dhcp
}

resource "proxmox_sdn_zone_vlan" "this" {
  for_each = { for k, v in var.zones : k => v if v.type == "vlan" }

  id     = each.key
  nodes  = each.value.nodes
  mtu    = each.value.mtu
  bridge = each.value.bridge

  ipam        = each.value.ipam
  dns         = each.value.dns
  dns_zone    = each.value.dns_zone
  reverse_dns = each.value.reverse_dns
}

resource "proxmox_sdn_zone_qinq" "this" {
  for_each = { for k, v in var.zones : k => v if v.type == "qinq" }

  id                    = each.key
  nodes                 = each.value.nodes
  mtu                   = each.value.mtu
  bridge                = each.value.bridge
  service_vlan          = each.value.service_vlan
  service_vlan_protocol = each.value.service_vlan_protocol

  ipam        = each.value.ipam
  dns         = each.value.dns
  dns_zone    = each.value.dns_zone
  reverse_dns = each.value.reverse_dns
}

resource "proxmox_sdn_zone_vxlan" "this" {
  for_each = { for k, v in var.zones : k => v if v.type == "vxlan" }

  id    = each.key
  nodes = each.value.nodes
  mtu   = each.value.mtu
  peers = each.value.peers

  ipam        = each.value.ipam
  dns         = each.value.dns
  dns_zone    = each.value.dns_zone
  reverse_dns = each.value.reverse_dns
}

resource "proxmox_sdn_zone_evpn" "this" {
  for_each = { for k, v in var.zones : k => v if v.type == "evpn" }

  id         = each.key
  nodes      = each.value.nodes
  mtu        = each.value.mtu
  controller = each.value.controller
  vrf_vxlan  = each.value.vrf_vxlan

  advertise_subnets          = each.value.advertise_subnets
  disable_arp_nd_suppression = each.value.disable_arp_nd_suppression
  exit_nodes                 = each.value.exit_nodes
  exit_nodes_local_routing   = each.value.exit_nodes_local_routing
  primary_exit_node          = each.value.primary_exit_node
  rt_import                  = each.value.rt_import

  ipam        = each.value.ipam
  dns         = each.value.dns
  dns_zone    = each.value.dns_zone
  reverse_dns = each.value.reverse_dns
}
