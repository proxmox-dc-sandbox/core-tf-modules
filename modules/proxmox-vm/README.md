# proxmox-vm

Proxmox VE virtual machines for `03-compute`: cloud-init, ISO and clone
flavors, disks, and network interfaces. Consumed by the compute layer;
usable standalone from any client project.

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `vms` | `map(object)` | — | VMs to manage. Key = VM name. Each object: `target_node`, `os_image` + `cloud_init` (snippet/init datastores, `template_file`, `ssh_keys`, `template_vars`) or `iso_file` or `clone_from` (mutually exclusive), `cores`, `cpu_type`, `memory`, `serial`, `disks` (scsi, storage = datastore ID or role), `interfaces` (vnet, ip/gw, mac, model, firewall). See `variables.tf` for the full object contract and the per-field validations. |

## Outputs

| Name | Description |
|------|-------------|
| `vm_ids` | Resource id per VM name. |
| `vm_vmid` | Proxmox numeric VMID per VM name. |
| `ipv4_addresses` | First IPv4 address per VM name (agent). |
| `ipv6_addresses` | First IPv6 address per VM name (agent). |
| `cloud_init_file_ids` | Generated cloud-init snippet file id per VM name. |

## Usage

Called by `03-compute` with the VM catalogue; the caller resolves the
storage roles beforehand (see `modules/storage-resolution`) and passes the
cloud-init template directory (`template_file` is rendered with
`ssh_keys` + `template_vars`). Full example: `03-compute/examples/test-local`.

## Compatibility

- OpenTofu `>= 1.8.0`, provider `bpg/proxmox` (see the root README
  "Provider compatibility").
- No provider configuration and no backend here: the client project owns
  them.
