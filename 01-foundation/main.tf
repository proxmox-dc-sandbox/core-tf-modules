# ---------------------------------------------------------------------------
# FOUNDATION: the underlay and the global objects of the datacenter.
#   - Linux bridges (vmbrX)
#   - SDN Zones (sdn-zone module)
#   - OS images (cloud images + ISOs) and LXC templates downloaded on the nodes
#
# This is the first module of the stack. It has no backend and no provider
# configuration: both are supplied by the caller (Terragrunt or examples/).
# ---------------------------------------------------------------------------

resource "proxmox_network_linux_bridge" "bridges" {
  for_each = var.linux_bridges

  node_name  = each.value.node_name
  name       = each.key
  address    = each.value.address
  address6   = each.value.address6
  comment    = each.value.comment
  mtu        = each.value.mtu
  ports      = each.value.ports
  vlan_aware = each.value.vlan_aware
  vids       = each.value.vids

  # Do not recreate the bridge if someone edited the comment manually.
  lifecycle {
    ignore_changes = [comment]
  }
}

module "zones" {
  source = "../modules/sdn-zone"
  zones  = var.sdn_zones

  # Creation and destroy ordering between the zones and the EVPN
  # controllers they reference, within a single state: controllers are
  # created first, zones are destroyed first. Client projects no longer
  # need to own the zone in a separate Terragrunt unit for teardown
  # ordering (the previous split-unit trick).
  depends_on = [proxmox_sdn_controller_evpn.controllers]
}

# --- SDN controllers: EVPN (referenced by evpn zones) and BGP (peering) -----
resource "proxmox_sdn_controller_evpn" "controllers" {
  for_each = { for k, v in var.sdn_controllers : k => v if v.type == "evpn" }

  id     = each.key
  asn    = each.value.asn
  peers  = each.value.peers
  fabric = each.value.fabric
}

# Plain BGP controllers (e.g. peering with an external router such as a
# MikroTik CHR) — backported from the client-side `generate` workaround.
resource "proxmox_sdn_controller_bgp" "controllers" {
  for_each = { for k, v in var.sdn_controllers : k => v if v.type == "bgp" }

  id        = each.key
  asn       = each.value.asn
  node_name = each.value.node_name
  peers     = each.value.peers
  ebgp      = each.value.ebgp
}

locals {
  evpn_controller_ids = [for k, v in var.sdn_controllers : k if v.type == "evpn"]
}

resource "proxmox_download_file" "os_images" {
  for_each = var.os_images

  content_type       = each.value.content_type
  datastore_id       = local.datastore_of["${each.value.node}:${each.value.datastore}"]
  node_name          = each.value.node
  url                = each.value.url
  file_name          = each.value.file_name
  checksum           = each.value.checksum
  checksum_algorithm = each.value.checksum_algorithm
  overwrite          = each.value.overwrite
}

resource "proxmox_download_file" "lxc_templates" {
  for_each = var.lxc_templates

  content_type = "vztmpl"
  datastore_id = local.datastore_of["${each.value.node}:${each.value.datastore}"]
  node_name    = each.value.node
  url          = each.value.url
  file_name    = each.value.file_name
}

# ---------------------------------------------------------------------------
# Storage: discovery (capabilities), role resolution, optional creation
# ---------------------------------------------------------------------------

locals {
  # Nodes involved in storage usage: images, templates and storages to create.
  storage_nodes = distinct(concat(
    [for v in var.os_images : v.node],
    [for v in var.lxc_templates : v.node],
    flatten([for v in var.storages : v.nodes == null ? [] : v.nodes]),
  ))

  # Every (node, storage ref) used by the download resources.
  storage_refs = flatten([
    for node in local.storage_nodes : [
      for ref in distinct([
        for v in concat(values(var.os_images), values(var.lxc_templates)) : v.datastore if v.node == node
        ]) : {
        node = node
        ref  = ref
      }
    ]
  ])
}

# Single resolution module: discovers the datastores of every node involved,
# resolves the storage roles and every (node, ref) used by the download
# resources. Pure computation + one read-only data source per node.
module "storage_resolution" {
  source       = "../modules/storage-resolution"
  nodes        = toset(local.storage_nodes)
  storage_refs = local.storage_refs
  roles        = var.storage_roles
}

locals {
  datastore_of       = module.storage_resolution.datastore_of
  unresolved_storage = module.storage_resolution.unresolved_storage
}

# --- Optional storage creation (one resource block per backend type) --------

resource "proxmox_storage_directory" "this" {
  for_each = { for id, s in var.storages : id => s if s.type == "directory" }

  id      = each.key
  path    = each.value.path
  content = each.value.content
  nodes   = each.value.nodes
  shared  = each.value.shared
  disable = false

  # The API may not report `nodes` for local storages; avoid fighting the cluster over it.
  lifecycle {
    ignore_changes = [nodes]
  }
}

resource "proxmox_storage_nfs" "this" {
  for_each = { for id, s in var.storages : id => s if s.type == "nfs" }

  id      = each.key
  server  = each.value.server
  export  = each.value.export
  content = each.value.content
  nodes   = each.value.nodes
  disable = false

  lifecycle {
    ignore_changes = [nodes]
  }
}

resource "proxmox_storage_lvm" "this" {
  for_each = { for id, s in var.storages : id => s if s.type == "lvm" }

  id           = each.key
  volume_group = each.value.volume_group
  content      = each.value.content
  nodes        = each.value.nodes
  shared       = each.value.shared
  disable      = false

  lifecycle {
    ignore_changes = [nodes]
  }
}

resource "proxmox_storage_lvmthin" "this" {
  for_each = { for id, s in var.storages : id => s if s.type == "lvmthin" }

  id           = each.key
  volume_group = each.value.volume_group
  thin_pool    = each.value.thin_pool
  content      = each.value.content
  nodes        = each.value.nodes
  disable      = false

  lifecycle {
    ignore_changes = [nodes]
  }
}

resource "proxmox_storage_zfspool" "this" {
  for_each = { for id, s in var.storages : id => s if s.type == "zfspool" }

  id       = each.key
  zfs_pool = each.value.zfs_pool
  content  = each.value.content
  nodes    = each.value.nodes
  disable  = false

  lifecycle {
    ignore_changes = [nodes]
  }
}
