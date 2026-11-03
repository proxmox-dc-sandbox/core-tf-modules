output "datastore_of" {
  description = "Resolved datastore id per (node, ref) pair, keyed \"node:ref\" (null when unresolved)."
  value       = local.datastore_of
}

output "unresolved_storage" {
  description = "Unresolved (node, ref) pairs, as \"node:ref\" strings."
  value       = local.unresolved_storage
}

output "role_datastores" {
  description = "Resolved datastore id per role, per node (map: node -> role -> datastore id, null when unresolved)."
  value       = local.role_datastores
}

output "unresolved_roles" {
  description = "Unresolved role names, per node."
  value       = local.unresolved_roles
}

output "diagnostics" {
  description = "Human-readable role-resolution error per node (null when everything resolved) — for the calling layer's check blocks."
  value       = local.diagnostics
}

output "datastore_catalog" {
  description = "Datastore capabilities per node (map: node -> datastore id -> content types)."
  value       = local.datastore_catalog
}
