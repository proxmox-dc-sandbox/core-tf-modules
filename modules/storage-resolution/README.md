# storage-resolution

Maps the storage references used by a layer (`01-foundation` downloads,
`03-compute` VM disks and cloud-init) to real Proxmox datastore IDs, and
resolves logical storage roles along the way. Pure computation plus one
read-only `proxmox_datastores` data source per node — no resources, no side
effects.

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `nodes` | `set(string)` | — | Nodes the datastores are discovered on. |
| `storage_refs` | `list(object({node, ref}))` | `[]` | Every (node, ref) pair to resolve. A ref is an explicit datastore ID or a role name. |
| `roles` | `map(object({content, datastore?}))` | `{}` | Role -> required content types; `datastore` pins the choice instead of auto-selecting. |

## Outputs

| Name | Description |
|------|-------------|
| `datastore_of` | Resolved datastore id per `"node:ref"` key (null when unresolved). |
| `unresolved_storage` | Unresolved `"node:ref"` strings (empty when everything resolves). |
| `role_datastores` | Resolved datastore per role, per node. |
| `unresolved_roles` | Unresolved role names, per node. |
| `diagnostics` | Per-node human-readable resolution error (null when resolved) — meant for the calling layer's `check` blocks. |
| `datastore_catalog` | Datastore capabilities per node (id -> content types). |

## Resolution rules

1. If the ref matches an existing datastore ID on the node, it passes through.
2. Otherwise, if it matches a role defined in `roles`, the role is resolved:
   a pinned `datastore` wins; else the first datastore (alphabetical order)
   whose content types contain **all** the role's required content types.
3. Anything else is reported unresolved (the calling layer fails with the
   per-node diagnostics).

This module absorbs the former `modules/storage-roles` (removed in the same
release). The calling layers keep their `storage_roles` input variable and
their `check` blocks unchanged — they now consume this module's outputs.

## Compatibility

- OpenTofu `>= 1.8.0`, provider `bpg/proxmox`.
- Consumed by `01-foundation` and `03-compute`; usable standalone from any
  client project that needs role-based datastore selection.
