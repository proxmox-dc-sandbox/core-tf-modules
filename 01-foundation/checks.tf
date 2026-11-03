# ---------------------------------------------------------------------------
# Cross-input validation checks (evaluated at plan/apply time).
# Same dedicated file as 02-networking and 03-compute.
# ---------------------------------------------------------------------------

check "evpn_controller_references" {
  assert {
    condition = alltrue([
      for k, v in var.sdn_zones : (v.type != "evpn" || contains(local.evpn_controller_ids, v.controller))
    ])
    error_message = <<-EOT
      Every zone of type "evpn" must reference an existing EVPN controller
      (define it in `sdn_controllers` with type "evpn"). EVPN zones without
      a controller:
      ${join(", ", [for k, v in var.sdn_zones : k if v.type == "evpn" && !contains(local.evpn_controller_ids, v.controller)])}
    EOT
  }
}

check "storage_refs_resolved" {
  assert {
    condition = length(local.unresolved_storage) == 0
    error_message = length(local.unresolved_storage) > 0 ? (
      format(
        "Unresolved storage references (create the storage or define a matching role in `storage_roles`):\n%s\n%s",
        join("\n", [for ref in local.unresolved_storage : "  - ${ref}"]),
        join("\n", [
          for node in local.storage_nodes :
          format("Node %s: %s", node, module.storage_resolution.diagnostics[node] != null ? module.storage_resolution.diagnostics[node] : "")
        ]),
      )
    ) : ""
  }
}
