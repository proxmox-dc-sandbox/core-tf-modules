# ---------------------------------------------------------------------------
# Storage resolution module inputs.
#
# The module discovers datastore capabilities on the given nodes and
# resolves every (node, ref) pair. It has no provider configuration: the
# caller supplies it (Terragrunt root.hcl or examples/test-local).
# ---------------------------------------------------------------------------

variable "nodes" {
  description = "Proxmox nodes involved in the storage resolution (the datastores are discovered on each)."
  type        = set(string)
}

variable "storage_refs" {
  description = <<-EOT
    Every (node, storage ref) pair used by the calling layer. A ref is either
    an explicit datastore ID (resolved as-is when it exists on the node) or
    a role name (resolved through `roles`). Duplicated pairs are ignored.
  EOT
  type = list(object({
    node = string
    ref  = string
  }))
  default = []
}

variable "roles" {
  description = <<-EOT
    Storage roles to resolve on each node: role name -> required content
    types (e.g. "iso", "vztmpl", "images", "snippets", "rootdir"). The
    datastore is auto-selected among the datastores supporting ALL the
    required content types (alphabetical first fit), unless pinned with
    `datastore`.
  EOT
  type = map(object({
    content   = set(string)
    datastore = optional(string) # pin a specific datastore instead of auto-selecting
  }))
  default = {}
}
