# ---------------------------------------------------------------------------
# Cross-module validation. Upstream values are passed in by the caller:
#   - var.vnets / var.bridges / var.os_images / var.lxc_templates
#     (foundation + networking outputs)
# ---------------------------------------------------------------------------

check "network_references" {
  assert {
    condition = alltrue(flatten([
      for vm in var.virtual_machines : [
        for iface in vm.interfaces : contains(
          keys(merge(
            var.vnets,
            { for name, id in var.bridges : name => name },
            { for b in var.extra_bridges : b => b },
          )),
          iface.vnet,
        )
      ]
    ]))
    error_message = <<-EOT
      A network target (vnet OR bridge) referenced in interfaces.vnet does not exist.
      Available vnets: ${join(", ", sort(keys(var.vnets)))}
      Available bridges: ${join(", ", sort(keys(var.bridges)))}
      (Add unmanaged bridges (vmbr0...) to the extra_bridges variable.)
    EOT
  }
}

check "container_network_references" {
  assert {
    condition = alltrue(flatten([
      for c in var.containers : [
        for iface in c.interfaces : contains(
          keys(merge(
            var.vnets,
            { for name, id in var.bridges : name => name },
            { for b in var.extra_bridges : b => b },
          )),
          iface.vnet,
        )
      ]
    ]))
    error_message = "A network target (vnet/bridge) referenced by a container does not exist. Apply the foundation and networking units first (or add the bridge to extra_bridges)."
  }
}

check "image_references" {
  assert {
    condition = alltrue(flatten([
      for vm in var.virtual_machines : [
        (vm.os_image != null ? contains(keys(var.os_images), vm.os_image) : true),
        (vm.iso_image != null ? contains(keys(var.os_images), vm.iso_image) : true),
      ]
    ]))
    error_message = <<-EOT
      A referenced OS image does not exist in the foundation module.
      Available images: ${join(", ", sort(keys(var.os_images)))}
    EOT
  }
}

check "lxc_template_references" {
  assert {
    condition = alltrue([
      for c in var.containers : contains(keys(var.lxc_templates), c.template)
    ])
    error_message = <<-EOT
      A referenced LXC template does not exist in the foundation module.
      Available templates: ${join(", ", sort(keys(var.lxc_templates)))}
    EOT
  }
}

check "storage_refs_resolved" {
  assert {
    condition = length(local.unresolved_storage) == 0
    error_message = length(local.unresolved_storage) > 0 ? (
      format(
        "Unresolved storage references (create the storage in the foundation module or define a matching role in `storage_roles`):\n%s\n%s",
        join("\n", [for ref in local.unresolved_storage : "  - ${ref}"]),
        join("\n", [
          for node in local.compute_nodes :
          format("Node %s: %s", node, module.storage_resolution.diagnostics[node] != null ? module.storage_resolution.diagnostics[node] : "")
        ]),
      )
    ) : ""
  }
}
