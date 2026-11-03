variable "zones" {
  description = <<-EOT
    SDN zones to create. Key = zone id (e.g. DMZ, EDGE, LAB).

    Supported zone types (field `type`):
    - `simple` : isolated per-node bridge (default), no physical interface.
    - `vlan`   : uses an existing local bridge (e.g. vmbr0) + VLAN tags from the vnets.
    - `qinq`   : VLAN stacking (service VLAN + inner VLAN from the vnets).
    - `vxlan`  : overlay tunnel between peers (UDP 4789).
    - `evpn`   : routable L3 zone with an EVPN controller (multi-cluster).
  EOT
  type = map(object({
    type  = optional(string, "simple")
    nodes = list(string)
    mtu   = optional(number, 1500)

    # Shared optional attributes
    ipam        = optional(string)
    dns         = optional(string)
    dns_zone    = optional(string)
    reverse_dns = optional(string)

    # simple only
    dhcp = optional(string)

    # vlan / qinq only
    bridge = optional(string)

    # qinq only
    service_vlan          = optional(number)
    service_vlan_protocol = optional(string, "802.1ad")

    # vxlan only
    peers = optional(list(string))

    # evpn only
    controller                 = optional(string)
    vrf_vxlan                  = optional(number)
    advertise_subnets          = optional(bool, false)
    disable_arp_nd_suppression = optional(bool, false)
    exit_nodes                 = optional(list(string))
    exit_nodes_local_routing   = optional(bool, false)
    primary_exit_node          = optional(string)
    rt_import                  = optional(string)
  }))

  validation {
    condition = alltrue([
      for zone in var.zones : contains(["simple", "vlan", "qinq", "vxlan", "evpn"], zone.type)
    ])
    error_message = "Zone `type` must be one of: simple, vlan, qinq, vxlan, evpn."
  }

  validation {
    condition = alltrue([
      for zone in var.zones : zone.mtu == null || (zone.mtu >= 576 && zone.mtu <= 9000)
    ])
    error_message = "MTU must be between 576 and 9000."
  }

  validation {
    condition = alltrue([
      for zone in var.zones : (zone.type == "vlan" || zone.type == "qinq") ? zone.bridge != null : true
    ])
    error_message = "Zone type `vlan` and `qinq` require `bridge` (an existing local bridge, e.g. vmbr0)."
  }

  validation {
    condition = alltrue([
      for zone in var.zones : zone.type == "qinq" ? zone.service_vlan != null : true
    ])
    error_message = "Zone type `qinq` requires `service_vlan` (1-4094)."
  }

  validation {
    condition = alltrue([
      for zone in var.zones : zone.type == "qinq" ? contains(["802.1ad", "802.1q"], zone.service_vlan_protocol) : true
    ])
    error_message = "`service_vlan_protocol` must be `802.1ad` or `802.1q`."
  }

  validation {
    condition = alltrue([
      for zone in var.zones : zone.type == "vxlan" ? zone.peers != null && length(zone.peers) > 0 : true
    ])
    error_message = "Zone type `vxlan` requires `peers` (list of node IPs)."
  }

  validation {
    condition = alltrue([
      for zone in var.zones : zone.type == "evpn" ? (zone.controller != null && zone.vrf_vxlan != null) : true
    ])
    error_message = "Zone type `evpn` requires `controller` and `vrf_vxlan`."
  }
}
