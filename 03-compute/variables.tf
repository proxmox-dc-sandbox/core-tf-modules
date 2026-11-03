# ---------------------------------------------------------------------------
# Compute module inputs.
#
# Provider authentication/connection settings are NOT module inputs: they are
# configured by the caller (Terragrunt root.hcl or examples/test-local).
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Upstream data (foundation + networking module outputs)
# ---------------------------------------------------------------------------
variable "vnets" {
  description = "Map of vnet id -> vnet id (networking output `vnets`). Used to resolve interfaces[].vnet by name."
  type        = map(string)
  default     = {}
}

variable "bridges" {
  description = "Map of Linux bridge name -> bridge id (foundation output `bridges`). Used to resolve interfaces[].vnet by name."
  type        = map(string)
  default     = {}
}

variable "os_images" {
  description = "Map of image key -> file id (foundation output `os_images`). Used to resolve os_image / iso_image by name."
  type        = map(string)
  default     = {}
}

variable "lxc_templates" {
  description = "Map of template key -> file id (foundation output `lxc_templates`). Used to resolve containers[].template by name."
  type        = map(string)
  default     = {}
}

variable "cloud_init_templates_dir" {
  description = <<-EOT
    Directory containing the cloud-init templates (client-owned, NOT shipped
    with the modules). `cloud_init.template_file` is resolved relatively to
    this directory unless it is an absolute path.
    In Terragrunt, point it to the unit directory's cloud-init-templates
    folder (get_terragrunt_dir() + "/cloud-init-templates").
  EOT
  type        = string
  default     = null
}

# ---------------------------------------------------------------------------
# Compute: the tenants (VMs / containers)
# ---------------------------------------------------------------------------
variable "virtual_machines" {
  description = <<-EOT
    VMs to deploy. Key = VM name.

    - `os_image`  : key of an image from foundation (cloud image), imported on scsi0.
    - `iso_image` : key of an ISO from foundation (OPNsense, ...), attached as cdrom.
    - `clone_from`: VMID of a golden VM (built once) — the VM is cloned with
                    `proxmox_cloned_vm`. Excludes os_image / iso_image /
                    cloud_init (the clone takes everything from the golden VM).
                    `interfaces` (network) and `disks` may be left empty to
                    keep the golden VM's own configuration.
    - `vnet` in interfaces : key of a vnet from networking (or a bridge name).
    - `cpu_type` : x86-64-v2-AES, host, EPYC-*, ...
  EOT
  type = map(object({
    target_node = string
    vm_id       = optional(number)
    description = optional(string)
    tags        = optional(list(string), [])
    on_boot     = optional(bool, true)
    started     = optional(bool, true)
    machine     = optional(string, "pc")
    bios        = optional(string, "seabios")
    boot_order  = optional(list(string))
    serial      = optional(bool, false)

    os_image   = optional(string)
    iso_image  = optional(string)
    clone_from = optional(number) # golden VMID to clone

    cores     = optional(number)       # null = 1 (cloud-init) / inherited from the golden VM (clone)
    sockets   = optional(number)       # null = 1 (cloud-init) / inherited from the golden VM (clone)
    cpu_type  = optional(string)       # null = x86-64-v2-AES / inherited from the golden VM (clone)
    numa      = optional(bool)         # null = false / inherited from the golden VM (clone)
    cpu_flags = optional(list(string)) # null = [] / inherited from the golden VM (clone)

    memory        = optional(number) # null = 512 (cloud-init) / inherited from the golden VM (clone)
    memory_shared = optional(number) # null = 0 (cloud-init) / inherited from the golden VM (clone)

    agent = optional(bool, false)

    cloud_init = optional(object({
      snippet_datastore = string
      init_datastore    = optional(string) # storage for the cloud-init ISO (needs "images"); defaults to snippet_datastore
      template_file     = string           # relative to cloud_init_templates_dir, or absolute
      ssh_keys          = optional(list(string), [])
      template_vars     = optional(map(string), {})
      dns_servers       = optional(list(string))
    }))
    interfaces = optional(map(object({
      vnet        = string
      vlan        = optional(number)
      ip          = optional(string)
      gw          = optional(string)
      ipv6        = optional(string)
      gw6         = optional(string)
      model       = optional(string, "virtio")
      firewall    = optional(bool, false)
      mac_address = optional(string)
    })), {})
    disks = optional(map(object({
      storage   = string
      size      = number
      interface = optional(string)
      discard   = optional(string, "ignore")
      ssd       = optional(bool, false)
      iothread  = optional(bool, false)
      cache     = optional(string, "none")
    })), {})
  }))

  validation {
    condition = alltrue([
      for k, v in var.virtual_machines : (v.os_image != null || v.iso_image != null || v.clone_from != null)
    ])
    error_message = "Each VM must define `os_image` (cloud image), `iso_image` (ISO/cdrom) or `clone_from` (golden VMID to clone)."
  }

  validation {
    condition = alltrue([
      for k, v in var.virtual_machines : (v.clone_from == null || (v.os_image == null && v.iso_image == null && v.cloud_init == null))
    ])
    error_message = "`clone_from` cannot be combined with `os_image`, `iso_image` or `cloud_init` (the clone inherits everything from the golden VM)."
  }

  validation {
    condition = alltrue(flatten([
      for k, v in var.virtual_machines : [
        for key in(v.cloud_init != null ? v.cloud_init.ssh_keys : []) : can(regex(local.ssh_key_pattern, key))
      ]
    ]))
    error_message = "`cloud_init.ssh_keys` contains an invalid SSH public key. Expected format: \"<algorithm> <base64-data> [comment]\" (e.g. \"ssh-ed25519 AAAA...\")."
  }
}

variable "extra_bridges" {
  description = "Plain bridges assumed to exist on the nodes but not managed by tofu (e.g. vmbr0)."
  type        = list(string)
  default     = []
}

variable "storage_roles" {
  description = <<-EOT
    Storage roles resolved against the node's datastores (see the foundation
    module). Used by `cloud_init.snippet_datastore`, `cloud_init.init_datastore`
    and `disks[].storage`: each may reference a role name or a real datastore ID.
    Each role maps to the content types it requires (e.g. "snippets", "images", "rootdir").
  EOT
  type = map(object({
    content   = set(string)
    datastore = optional(string) # pin a specific datastore instead of auto-selecting
  }))
  default = {}
}

locals {
  # ssh_keys must look like: "<algorithm> <base64-data> [comment]"
  ssh_key_pattern = "^[a-z0-9-]+ [A-Za-z0-9+/=]+( .+)?$"
}

variable "containers" {
  description = "LXC containers to deploy (optional). `template` refers to a key of `lxc_templates` from the foundation module."
  type = map(object({
    target_node  = string
    template     = string
    os_type      = string # alpine, ubuntu, debian, ...
    cores        = number
    memory       = number
    ssh_keys     = optional(list(string), [])
    unprivileged = optional(bool, true)
    interfaces = map(object({
      vnet = string
      ip   = string
      gw   = optional(string)
      vlan = optional(number)
    }))
    disks = map(object({
      storage = string
      size    = number
    }))
  }))
  default = {}

  validation {
    condition = alltrue(flatten([
      for c in var.containers : [
        for k in c.ssh_keys : can(regex(local.ssh_key_pattern, k))
      ]
    ]))
    error_message = "`containers[].ssh_keys` contains an invalid SSH public key. Expected format: \"<algorithm> <base64-data> [comment]\" (e.g. \"ssh-ed25519 AAAA...\")."
  }

  validation {
    condition = alltrue([
      for k, v in var.containers : can(regex("^[a-z0-9-]+$", v.os_type))
    ])
    error_message = "`containers[].os_type` must be a simple OS identifier (alpine, ubuntu, debian, ...)."
  }
}
