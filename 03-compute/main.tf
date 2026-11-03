# ---------------------------------------------------------------------------
# COMPUTE: the tenants (OPNsense / bastion / server VMs + LXC).
#   - No network resource here: vnets/images are passed in by the caller
#     (Terragrunt dependency outputs).
#   - The proxmox-vm module is called with a "clean" config: vnet and image
#     names only, no IDs.
#
# This module has no backend and no provider configuration.
# ---------------------------------------------------------------------------

locals {
  vnet_ids  = var.vnets
  image_ids = var.os_images

  # Valid network targets for network_device.bridge: SDN vnets (networking)
  # + managed Linux bridges (foundation) + "extra" bridges (not managed by
  # tofu, e.g. vmbr0). All referenced by NAME.
  network_targets = merge(
    var.vnets,
    { for name, id in var.bridges : name => name },
    { for b in var.extra_bridges : b => b },
  )

  # Directory containing the client-owned cloud-init templates. The templates
  # are NOT shipped by the modules (portability); the caller points this to
  # its own directory.
  cloud_init_templates_dir = var.cloud_init_templates_dir != null ? var.cloud_init_templates_dir : path.root

  # --- Storage: role-based datastore resolution -----------------------------
  compute_nodes = distinct(concat(
    [for vm in var.virtual_machines : vm.target_node],
    [for c in var.containers : c.target_node],
  ))

  # Every (node, storage ref) used by VMs (disks + cloud-init) and containers.
  storage_refs = distinct(flatten([
    [
      for vm_name, vm in var.virtual_machines : concat(
        [for disk_name, d in vm.disks : { node = vm.target_node, ref = d.storage }],
        vm.cloud_init != null ? [
          { node = vm.target_node, ref = vm.cloud_init.snippet_datastore },
        ] : [],
        vm.cloud_init != null && vm.cloud_init.init_datastore != null ? [
          { node = vm.target_node, ref = vm.cloud_init.init_datastore },
        ] : [],
      )
    ],
    [
      for c_name, c in var.containers : [
        for disk_name, d in c.disks : { node = c.target_node, ref = d.storage }
      ]
    ],
  ]))

  # Transformation of the declarative config (logical names) into the module input.
  # VMs with `clone_from` are handled by proxmox_cloned_vm below.
  vm_configs = {
    for vm_name, vm in var.virtual_machines : vm_name => {
      node_name       = vm.target_node
      vm_id           = vm.vm_id
      name            = vm_name
      description     = vm.description
      tags            = vm.tags
      on_boot         = vm.on_boot
      started         = vm.started
      machine         = vm.machine
      bios            = vm.bios
      boot_order      = vm.boot_order
      serial_device   = vm.serial
      stop_on_destroy = vm.iso_image != null

      cpu = {
        cores   = vm.cores != null ? vm.cores : 1
        sockets = vm.sockets != null ? vm.sockets : 1
        type    = vm.cpu_type != null ? vm.cpu_type : "x86-64-v2-AES"
        numa    = vm.numa != null ? vm.numa : false
        flags   = vm.cpu_flags != null ? vm.cpu_flags : []
      }

      memory = {
        dedicated = vm.memory != null ? vm.memory : 512
        shared    = vm.memory_shared != null ? vm.memory_shared : 0
      }

      agent = vm.agent ? { enabled = true, type = "virtio", trim = false } : null

      network_devices = {
        for iface_name, iface in vm.interfaces : iface_name => {
          bridge      = local.network_targets[iface.vnet]
          vlan_id     = iface.vlan
          mac_address = iface.mac_address
          model       = iface.model
          firewall    = iface.firewall
          ip_config = {
            ipv4 = {
              address = iface.ip != null ? iface.ip : "dhcp"
              gateway = iface.gw
            }
            ipv6 = iface.ipv6 != null ? {
              address = iface.ipv6
              gateway = iface.gw6
            } : null
          }
        }
      }

      disks = {
        for disk_name, d in vm.disks : disk_name => {
          datastore_id = local.datastore_of["${vm.target_node}:${d.storage}"]
          size         = d.size
          interface    = d.interface
          file_id      = (disk_name == "scsi0" && vm.os_image != null) ? local.image_ids[vm.os_image] : null
          discard      = d.discard
          ssd          = d.ssd
          iothread     = d.iothread
          cache        = d.cache
        }
      }

      cloud_init = vm.cloud_init != null ? {
        datastore_id   = local.datastore_of["${vm.target_node}:${vm.cloud_init.snippet_datastore}"]
        init_datastore = vm.cloud_init.init_datastore != null ? local.datastore_of["${vm.target_node}:${vm.cloud_init.init_datastore}"] : null
        template_file = (
          startswith(vm.cloud_init.template_file, "/")
          ? vm.cloud_init.template_file
          : "${local.cloud_init_templates_dir}/${vm.cloud_init.template_file}"
        )
        ssh_keys      = vm.cloud_init.ssh_keys
        template_vars = vm.cloud_init.template_vars
        dns_servers   = vm.cloud_init.dns_servers
      } : null

      cdrom = vm.iso_image != null ? {
        file_id = local.image_ids[vm.iso_image]
      } : null
    } if vm.clone_from == null
  }
}

module "vms" {
  source = "../modules/proxmox-vm"
  vms    = local.vm_configs
}

# ---------------------------------------------------------------------------
# Golden-image clones: VMs with `clone_from` are cloned from a golden VM
# (built once) instead of being provisioned from cloud-init / ISO. Only the
# network and identity are overridden on the clone.
# ---------------------------------------------------------------------------
locals {
  clone_configs = {
    for vm_name, vm in var.virtual_machines : vm_name => vm if vm.clone_from != null
  }
}

resource "proxmox_cloned_vm" "clones" {
  for_each = local.clone_configs

  node_name = each.value.target_node
  id        = each.value.vm_id
  name      = each.key
  started   = each.value.started

  clone = {
    source_vm_id = each.value.clone_from
    full         = true
  }

  # CPU/RAM: null fields -> inherit the golden VM's values.
  cpu = (
    each.value.cores == null && each.value.sockets == null &&
    each.value.cpu_type == null && each.value.numa == null &&
    length(each.value.cpu_flags != null ? each.value.cpu_flags : []) == 0
    ) ? null : {
    cores   = each.value.cores != null ? each.value.cores : 1
    sockets = each.value.sockets != null ? each.value.sockets : 1
    type    = each.value.cpu_type != null ? each.value.cpu_type : "x86-64-v2-AES"
    numa    = each.value.numa != null ? each.value.numa : false
    flags   = each.value.cpu_flags != null ? each.value.cpu_flags : []
  }
  memory = each.value.memory == null && each.value.memory_shared == null ? null : {
    size    = each.value.memory != null ? each.value.memory : 512
    balloon = each.value.memory_shared != null ? each.value.memory_shared : 0
  }

  network = {
    for iface_name, iface in each.value.interfaces : iface_name => {
      bridge      = local.network_targets[iface.vnet]
      tag         = iface.vlan
      mac_address = iface.mac_address
      model       = iface.model
      firewall    = iface.firewall
    }
  }

  lifecycle {
    ignore_changes = [description]
  }
}

# ---------------------------------------------------------------------------
# Storage: discover datastore capabilities and resolve roles (snippets,
# images, rootdir, ...) per node.
# ---------------------------------------------------------------------------
# Single resolution module (same engine as 01-foundation): discovers the
# datastores of every compute node, resolves the storage roles and every
# (node, ref) used by the VMs and containers.
module "storage_resolution" {
  source       = "../modules/storage-resolution"
  nodes        = toset(local.compute_nodes)
  storage_refs = local.storage_refs
  roles        = var.storage_roles
}

locals {
  datastore_of       = module.storage_resolution.datastore_of
  unresolved_storage = module.storage_resolution.unresolved_storage
}

# ---------------------------------------------------------------------------
# LXC containers (optional)
# ---------------------------------------------------------------------------
resource "proxmox_virtual_environment_container" "lxcs" {
  for_each = var.containers

  node_name    = each.value.target_node
  unprivileged = each.value.unprivileged

  initialization {
    hostname = each.key

    dynamic "user_account" {
      for_each = length(each.value.ssh_keys) > 0 ? [1] : []
      content {
        keys = each.value.ssh_keys
      }
    }

    # One ip_config entry per network interface, in the same order.
    dynamic "ip_config" {
      for_each = each.value.interfaces
      content {
        ipv4 {
          address = ip_config.value.ip
          gateway = ip_config.value.gw
        }
      }
    }
  }

  cpu {
    architecture = "amd64"
    cores        = each.value.cores
  }

  memory {
    dedicated = each.value.memory
  }

  operating_system {
    template_file_id = var.lxc_templates[each.value.template]
    type             = each.value.os_type
  }

  dynamic "network_interface" {
    for_each = each.value.interfaces
    content {
      name    = network_interface.key
      bridge  = local.network_targets[network_interface.value.vnet]
      vlan_id = network_interface.value.vlan
    }
  }

  dynamic "disk" {
    for_each = each.value.disks
    content {
      datastore_id = local.datastore_of["${each.value.target_node}:${disk.value.storage}"]
      size         = disk.value.size
    }
  }

  lifecycle {
    ignore_changes = [
      initialization,
      network_interface,
      disk,
    ]
  }
}
