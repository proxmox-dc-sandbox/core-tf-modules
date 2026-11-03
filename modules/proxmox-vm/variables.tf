variable "vms" {
  description = <<-EOT
    Virtual machines to create. Key = VM name (used as the VM name unless `name` is set).

    Each VM supports:
    - cloud-init (user_data snippet rendered from a tftpl template) OR cdrom (ISO) - at least one is required.
    - cpu type selection (x86-64-v2-AES, host, ...), sockets, numa, flags.
    - multiple disks, multiple network devices with per-interface IP configuration.
  EOT
  type = map(object({
    node_name       = string
    vm_id           = optional(number)
    name            = optional(string)
    description     = optional(string)
    tags            = optional(list(string), [])
    on_boot         = optional(bool, true)
    started         = optional(bool, true)
    stop_on_destroy = optional(bool, false)
    machine         = optional(string, "pc")
    bios            = optional(string, "seabios")
    keyboard_layout = optional(string, "en-us")
    boot_order      = optional(list(string))

    cpu = object({
      cores   = number
      sockets = optional(number, 1)
      type    = optional(string, "x86-64-v2-AES")
      numa    = optional(bool, false)
      flags   = optional(list(string), [])
    })

    memory = object({
      dedicated = number
      shared    = optional(number, 0)
    })

    # If not set, no QEMU agent block is emitted (safe default for ISO-based VMs).
    agent = optional(object({
      enabled = optional(bool, true)
      type    = optional(string, "virtio")
      trim    = optional(bool, false)
    }))

    serial_device = optional(bool, false)

    network_devices = map(object({
      bridge      = string
      vlan_id     = optional(number)
      mac_address = optional(string)
      model       = optional(string, "virtio")
      firewall    = optional(bool, false)
      ip_config = optional(object({
        ipv4 = optional(object({
          address = string # "dhcp" or CIDR
          gateway = optional(string)
        }))
        ipv6 = optional(object({
          address = string # "dhcp", "auto" or CIDR
          gateway = optional(string)
        }))
      }))
    }))

    disks = map(object({
      datastore_id = string
      size         = number           # GiB
      interface    = optional(string) # defaults to the map key (scsi0, virtio1, ...)
      file_id      = optional(string) # e.g. downloaded cloud image id (boot disk)
      discard      = optional(string, "ignore")
      ssd          = optional(bool, false)
      iothread     = optional(bool, false)
      cache        = optional(string, "none")
    }))

    cloud_init = optional(object({
      datastore_id   = string           # storage receiving the rendered snippet (needs content type "snippets")
      init_datastore = optional(string) # storage for the generated cloud-init ISO (needs content type "images"); defaults to datastore_id
      template_file  = string           # absolute path to the .tftpl template (resolved by the compute module)
      ssh_keys       = optional(list(string), [])
      template_vars  = optional(map(string), {}) # extra string variables for the template
      dns_servers    = optional(list(string))
    }))

    cdrom = optional(object({
      file_id   = string # ISO file id (e.g. from proxmox_download_file)
      interface = optional(string, "ide3")
    }))
  }))

  validation {
    condition = alltrue([
      for k, v in var.vms : (v.cloud_init != null || v.cdrom != null)
    ])
    error_message = "Each VM must define either `cloud_init` or `cdrom`."
  }

  validation {
    condition = alltrue([
      for k, v in var.vms : length(v.network_devices) > 0
    ])
    error_message = "Each VM must define at least one network device."
  }

  validation {
    condition = alltrue([
      for k, v in var.vms : v.cloud_init == null || alltrue([
        for n, d in v.network_devices : d.ip_config != null
      ])
    ])
    error_message = "When `cloud_init` is set, every network device must define an `ip_config` (one ip_config block per network device, in the same order)."
  }

  validation {
    condition = alltrue([
      for k, v in var.vms : v.memory.dedicated >= 128
    ])
    error_message = "Memory must be at least 128 MB."
  }
}
