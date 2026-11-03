variable "vnets" {
  description = "SDN VNets to create. Key = vnet id (e.g. dmz, netlocal)."
  type = map(object({
    zone          = string
    vlan_aware    = optional(bool, false)
    alias         = optional(string)
    isolate_ports = optional(bool, false)
    tag           = optional(number)
  }))

  validation {
    condition = alltrue([
      for v in var.vnets : v.tag == null || (v.tag >= 1 && v.tag <= 4094)
    ])
    error_message = "VLAN tag must be between 1 and 4094."
  }
}
