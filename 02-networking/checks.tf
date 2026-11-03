# ---------------------------------------------------------------------------
# Cross-module validation: every vnet must reference a zone exposed by the
# foundation module. The caller passes `zones` (foundation output).
# ---------------------------------------------------------------------------
check "zones_exist" {
  assert {
    condition = alltrue([
      for v in var.sdn_vnets : contains(keys(var.zones), v.zone)
    ])
    error_message = <<-EOT
      One of the zones referenced by the vnets does not exist in the foundation
      module. Apply the foundation unit first and pass its `zones` output as the
      `zones` input of this module.
    EOT
  }
}
