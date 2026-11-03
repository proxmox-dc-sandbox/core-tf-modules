# ---------------------------------------------------------------------------
# Storage resolution: role assignment + (node, ref) resolution.
#
# Absorbs the former `modules/storage-roles` (role -> datastore mapping from
# the discovered content types) and the resolution locals that used to be
# duplicated verbatim in 01-foundation and 03-compute.
#
# Pure computation + one read-only data source per node; no side effects.
# ---------------------------------------------------------------------------

data "proxmox_datastores" "node" {
  for_each  = var.nodes
  node_name = each.key
}

locals {
  # node -> (datastore id -> content types)
  by_node = {
    for node in var.nodes : node => {
      for ds in data.proxmox_datastores.node[node].datastores : ds.id => toset(ds.content_types)
    }
  }

  # --- Role resolution per node (absorbed from the former storage-roles) ----
  # role -> datastore id (null when unresolvable); a pinned `datastore` wins,
  # otherwise first datastore (alphabetical order) whose content types
  # contain ALL the role's required content types.
  role_datastores = {
    for node in var.nodes : node => {
      for role, def in var.roles : role => (
        def.datastore != null ? def.datastore : (
          length(local.by_node[node]) == 0 ? null :
          try(element([
            for id in sort(keys(local.by_node[node])) :
            id if length(setintersection(local.by_node[node][id], def.content)) == length(def.content)
          ], 0), null)
        )
      )
    }
  }

  unresolved_roles = {
    for node in var.nodes : node => [
      for role, id in local.role_datastores[node] : role if id == null
    ]
  }

  # --- (node, ref) resolution: explicit datastore IDs pass through ---------
  datastore_of = {
    for r in distinct(var.storage_refs) :
    "${r.node}:${r.ref}" => (
      contains(keys(local.by_node[r.node]), r.ref)
      ? r.ref
      : lookup(local.role_datastores[r.node], r.ref, null)
    )
  }

  unresolved_storage = [
    for r in distinct(var.storage_refs) :
    "${r.node}:${r.ref}"
    if local.datastore_of["${r.node}:${r.ref}"] == null
  ]

  # --- Diagnostics -----------------------------------------------------------
  diagnostics = {
    for node in var.nodes : node => (
      length(local.unresolved_roles[node]) > 0 ?
      format(
        "Storage roles could not be resolved on this node:\n%s\nAvailable datastores:\n%s",
        join("\n", [
          for role in local.unresolved_roles[node] :
          "  - role \"${role}\" requires content types [${join(", ", sort(var.roles[role].content))}]"
        ]),
        length(keys(local.by_node[node])) > 0 ? join("\n", [
          for id in sort(keys(local.by_node[node])) :
          "  - ${id}: [${join(", ", sort(local.by_node[node][id]))}]"
        ]) : "  (none)",
      )
      : null
    )
  }

  # node -> (datastore id -> content types), for callers exposing a catalog.
  datastore_catalog = {
    for node in var.nodes : node => {
      for id, types in local.by_node[node] : id => sort(types)
    }
  }
}
