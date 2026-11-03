output "vm_ids" {
  description = "Map of VM name -> VM id."
  value = merge(
    module.vms.vm_ids,
    { for k, v in proxmox_cloned_vm.clones : k => v.id },
  )
}

output "vm_vmid" {
  description = "Map of VM name -> numeric VM id."
  value = merge(
    module.vms.vm_vmid,
    { for k, v in proxmox_cloned_vm.clones : k => v.vm_id },
  )
}

output "vm_ipv4_addresses" {
  description = "Map of VM name -> IPv4 addresses reported by the QEMU agent (empty without agent)."
  value = merge(
    module.vms.ipv4_addresses,
    { for k in keys(local.clone_configs) : k => [] },
  )
}

output "container_ids" {
  description = "Map of container name -> container id."
  value       = { for k, v in proxmox_virtual_environment_container.lxcs : k => v.id }
}

output "vnet_catalog" {
  description = "Vnets available (passed in from the networking module, useful for CI / tooling)."
  value       = var.vnets
}

output "image_catalog" {
  description = "Images available (passed in from the foundation module, useful for CI / tooling)."
  value       = var.os_images
}
