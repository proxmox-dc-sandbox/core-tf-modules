locals {
  with_cloud_init = {
    for k, v in var.vms : k => v if v.cloud_init != null
  }
}

# Cloud-init user-data snippet, rendered from a template and uploaded to the node.
# Only created for VMs that use cloud-init.
resource "proxmox_virtual_environment_file" "cloud_init" {
  for_each = local.with_cloud_init

  node_name    = each.value.node_name
  content_type = "snippets"
  datastore_id = each.value.cloud_init.datastore_id

  source_raw {
    data = templatefile(each.value.cloud_init.template_file, merge(
      { ssh_keys = each.value.cloud_init.ssh_keys },
      each.value.cloud_init.template_vars,
    ))
    file_name = "${each.key}-cloud-init.yaml"
  }
}

resource "proxmox_virtual_environment_vm" "this" {
  for_each = var.vms

  name            = each.value.name != null ? each.value.name : each.key
  node_name       = each.value.node_name
  vm_id           = each.value.vm_id
  description     = each.value.description
  tags            = sort(each.value.tags)
  on_boot         = each.value.on_boot
  started         = each.value.started
  stop_on_destroy = each.value.stop_on_destroy
  machine         = each.value.machine
  bios            = each.value.bios
  keyboard_layout = each.value.keyboard_layout
  boot_order      = each.value.boot_order

  cpu {
    cores   = each.value.cpu.cores
    sockets = each.value.cpu.sockets
    type    = each.value.cpu.type
    numa    = each.value.cpu.numa
    flags   = each.value.cpu.flags
  }

  memory {
    dedicated = each.value.memory.dedicated
    shared    = each.value.memory.shared
  }

  dynamic "agent" {
    for_each = each.value.agent != null ? [each.value.agent] : []
    content {
      enabled = agent.value.enabled
      type    = agent.value.type
      trim    = agent.value.trim
    }
  }

  dynamic "serial_device" {
    for_each = each.value.serial_device ? [1] : []
    content {
      device = "socket"
    }
  }

  dynamic "initialization" {
    for_each = each.value.cloud_init != null ? [each.value.cloud_init] : []
    content {
      datastore_id      = initialization.value.init_datastore != null ? initialization.value.init_datastore : initialization.value.datastore_id
      user_data_file_id = proxmox_virtual_environment_file.cloud_init[each.key].id

      dynamic "dns" {
        for_each = initialization.value.dns_servers != null ? [initialization.value.dns_servers] : []
        content {
          servers = dns.value
        }
      }

      # One ip_config block per network device, in the same order as network_device.
      dynamic "ip_config" {
        for_each = each.value.network_devices
        content {
          dynamic "ipv4" {
            for_each = ip_config.value.ip_config != null && ip_config.value.ip_config.ipv4 != null ? [1] : []
            content {
              address = ip_config.value.ip_config.ipv4.address
              gateway = ip_config.value.ip_config.ipv4.gateway
            }
          }
          dynamic "ipv6" {
            for_each = ip_config.value.ip_config != null && ip_config.value.ip_config.ipv6 != null ? [1] : []
            content {
              address = ip_config.value.ip_config.ipv6.address
              gateway = ip_config.value.ip_config.ipv6.gateway
            }
          }
        }
      }
    }
  }

  dynamic "network_device" {
    for_each = each.value.network_devices
    content {
      bridge      = network_device.value.bridge
      vlan_id     = network_device.value.vlan_id
      mac_address = network_device.value.mac_address
      model       = network_device.value.model
      firewall    = network_device.value.firewall
    }
  }

  dynamic "disk" {
    for_each = each.value.disks
    content {
      datastore_id = disk.value.datastore_id
      size         = disk.value.size
      interface    = disk.value.interface != null ? disk.value.interface : disk.key
      file_id      = disk.value.file_id
      discard      = disk.value.discard
      ssd          = disk.value.ssd
      iothread     = disk.value.iothread
      cache        = disk.value.cache
    }
  }

  dynamic "cdrom" {
    for_each = each.value.cdrom != null ? [each.value.cdrom] : []
    content {
      file_id   = cdrom.value.file_id
      interface = cdrom.value.interface
    }
  }

  lifecycle {
    ignore_changes = [
      # cloud-init / IP config changes are applied inside the guest, not via recreation
      initialization,
      # ISO can be swapped manually on the node
      cdrom,
    ]
  }
}
