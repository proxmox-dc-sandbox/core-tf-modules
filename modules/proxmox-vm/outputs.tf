output "vm_ids" {
  description = "Map of VM name -> VM id."
  value       = { for k, v in proxmox_virtual_environment_vm.this : k => v.id }
}

output "vm_vmid" {
  description = "Map of VM name -> numeric VM id."
  value       = { for k, v in proxmox_virtual_environment_vm.this : k => v.vm_id }
}

output "ipv4_addresses" {
  description = "Map of VM name -> IPv4 addresses reported by the QEMU agent (empty without agent)."
  value       = { for k, v in proxmox_virtual_environment_vm.this : k => v.ipv4_addresses }
}

output "ipv6_addresses" {
  description = "Map of VM name -> IPv6 addresses reported by the QEMU agent (empty without agent)."
  value       = { for k, v in proxmox_virtual_environment_vm.this : k => v.ipv6_addresses }
}

output "cloud_init_file_ids" {
  description = "Map of VM name -> cloud-init snippet file id."
  value       = { for k, v in proxmox_virtual_environment_file.cloud_init : k => v.id }
}
