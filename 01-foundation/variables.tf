# ---------------------------------------------------------------------------
# Foundation module inputs.
#
# Provider authentication/connection settings are NOT module inputs: they are
# configured by the caller (Terragrunt root.hcl or examples/test-local).
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Underlay: bridges, zones, images
# ---------------------------------------------------------------------------
variable "linux_bridges" {
  description = "Linux bridges (vmbrX) to create on the nodes."
  type = map(object({
    node_name  = string
    address    = optional(string)
    address6   = optional(string)
    comment    = optional(string)
    mtu        = optional(number)
    ports      = optional(list(string))
    vlan_aware = optional(bool, false)
    vids       = optional(string)
  }))
  default = {}
}

variable "sdn_zones" {
  description = <<-EOT
    SDN zones - global objects of the datacenter. `type` selects the zone model:
    simple (isolated per-node bridge), vlan (existing bridge + VLAN tags),
    qinq (VLAN stacking), vxlan (overlay peers), evpn (L3 multi-cluster).
  EOT
  type = map(object({
    type  = optional(string, "simple")
    nodes = list(string)
    mtu   = optional(number, 1500)

    ipam        = optional(string)
    dns         = optional(string)
    dns_zone    = optional(string)
    reverse_dns = optional(string)

    dhcp = optional(string) # simple only

    bridge = optional(string) # vlan / qinq only

    service_vlan          = optional(number)            # qinq only
    service_vlan_protocol = optional(string, "802.1ad") # qinq only

    peers = optional(list(string)) # vxlan only

    controller                 = optional(string) # evpn only
    vrf_vxlan                  = optional(number) # evpn only
    advertise_subnets          = optional(bool, false)
    disable_arp_nd_suppression = optional(bool, false)
    exit_nodes                 = optional(list(string))
    exit_nodes_local_routing   = optional(bool, false)
    primary_exit_node          = optional(string)
    rt_import                  = optional(string)
  }))
}

variable "os_images" {
  description = "OS images to download on the nodes (cloud images + ISOs)."
  type = map(object({
    node               = string
    datastore          = string
    url                = string
    file_name          = string
    content_type       = optional(string, "iso") # "iso" for cloud images / ISO, "import" for qcow2
    checksum           = optional(string)
    checksum_algorithm = optional(string)
    overwrite          = optional(bool, true)
  }))
}

variable "lxc_templates" {
  description = "LXC templates (vztmpl) to download on the nodes. `datastore` is a storage ID or a storage role (see `storage_roles`)."
  type = map(object({
    node      = string
    datastore = string
    url       = string
    file_name = string
  }))
  default = {}
}

# ---------------------------------------------------------------------------
# Storage: generic role-based selection + optional storage creation
# ---------------------------------------------------------------------------
variable "storage_roles" {
  description = <<-EOT
    Storage roles for this module. Key = role name referenced by
    `os_images[].datastore` / `lxc_templates[].datastore` (or directly usable
    by the upper modules). Each role maps to the content types it requires
    (e.g. "iso", "vztmpl", "images", "snippets", "rootdir"). The datastore is
    auto-selected on each node among the storages supporting ALL the required
    content types, unless pinned with `datastore`.
  EOT
  type = map(object({
    content   = set(string)
    datastore = optional(string) # pin a specific datastore instead of auto-selecting
  }))
  default = {}
}

variable "sdn_controllers" {
  description = <<-EOT
    SDN controllers to create (optional). `type` selects the model:
    "evpn" (L3 EVPN fabric, referenced by `sdn_zones[].controller` for
    `type = "evpn"` zones) or "bgp" (plain BGP peering, e.g. with an
    external router). Key = controller ID. An EVPN zone requires its
    controller to exist on the cluster (ASN mandatory). EVPN controllers
    can optionally be assigned to a `fabric` (proxmox_sdn_fabric_ospf/
    openfabric).
    NOTE: SDN IDs must match `^[A-Za-z][A-Za-z0-9]*[A-Za-z0-9]$` (alnum,
    max 8 chars, no dash/underscore — provider constraint).
  EOT
  type = map(object({
    type      = optional(string, "evpn") # "evpn" | "bgp"
    asn       = number                   # Autonomous System Number
    peers     = optional(list(string))   # BGP peer IP addresses
    fabric    = optional(string)         # evpn: fabric ID (openfabric/ospf)
    node_name = optional(string)         # bgp: node running the FRR instance
    ebgp      = optional(bool, false)    # bgp: external BGP
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.sdn_controllers : contains(["evpn", "bgp"], v.type)
    ])
    error_message = "Each controller `type` must be \"evpn\" or \"bgp\"."
  }

  validation {
    condition = alltrue([
      for k, v in var.sdn_controllers : (v.type != "evpn" || v.peers != null || v.fabric != null)
    ])
    error_message = "Each EVPN controller must define `peers` (BGP peer IPs) or `fabric` (provider constraint: at least one of [fabric, peers])."
  }

  validation {
    condition = alltrue([
      for k, v in var.sdn_controllers : (v.type != "bgp" || v.node_name != null)
    ])
    error_message = "Each BGP controller must define `node_name` (the node running the FRR instance)."
  }

  validation {
    condition = alltrue([
      for k, v in var.sdn_controllers : can(regex("^[A-Za-z][A-Za-z0-9]*[A-Za-z0-9]$", k)) && length(k) <= 8
    ])
    error_message = "Controller IDs must match ^[A-Za-z][A-Za-z0-9]*[A-Za-z0-9]$ and be at most 8 characters (no dash/underscore)."
  }
}

variable "storages" {
  description = <<-EOT
    Storages to create on the nodes (optional). Key = storage ID.
    `type` selects the Proxmox storage backend:
    directory | nfs | lvm | lvmthin | zfspool
    The content types must be listed in `content` (e.g. ["iso","vztmpl","snippets","images","rootdir"]).
  EOT
  type = map(object({
    type         = string
    path         = optional(string) # directory
    server       = optional(string) # nfs
    export       = optional(string) # nfs
    volume_group = optional(string) # lvm / lvmthin
    thin_pool    = optional(string) # lvmthin
    zfs_pool     = optional(string) # zfspool
    content      = optional(list(string))
    nodes        = optional(list(string))
    shared       = optional(bool, false)
  }))
  default = {}
}
