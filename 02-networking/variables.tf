# ---------------------------------------------------------------------------
# Networking module inputs.
#
# Provider authentication/connection settings are NOT module inputs: they are
# configured by the caller (Terragrunt root.hcl or examples/test-local).
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Upstream data (foundation module outputs)
# ---------------------------------------------------------------------------
variable "zones" {
  description = "Map of zone id -> zone id, as exposed by the foundation module. Used to validate vnet references."
  type        = map(string)
}

variable "zones_config" {
  description = "Fingerprint of the zone definitions (foundation output `zones_config`). Triggers an SDN re-apply on zone changes."
  type        = string
  default     = "{}"
}

variable "controllers_config" {
  description = "Fingerprint of the SDN controller definitions (foundation output `controllers_config`). Triggers an SDN re-apply on controller changes."
  type        = string
  default     = "{}"
}

# ---------------------------------------------------------------------------
# Overlay: vnets + subnets
# ---------------------------------------------------------------------------
variable "sdn_vnets" {
  description = "VNets to create. Key = vnet id. Each vnet references a zone created by the foundation module."
  type = map(object({
    zone          = string
    vlan_aware    = optional(bool, false)
    alias         = optional(string)
    isolate_ports = optional(bool, false)
    tag           = optional(number)
  }))
}

variable "sdn_subnets" {
  description = "Subnets to attach to the vnets. `dhcp_range` enables the SDN DHCP server (zone `dhcp = \"dnsmasq\"`) on this subnet."
  type = map(object({
    vnet            = string
    cidr            = string
    gateway         = optional(string)
    snat            = optional(bool, false)
    dhcp_dns_server = optional(string)
    dhcp_range = optional(object({
      start_address = string
      end_address   = string
    }))
    dns_zone_prefix = optional(string)
  }))
}
