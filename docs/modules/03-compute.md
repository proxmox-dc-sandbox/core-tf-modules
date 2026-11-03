# Module `03-compute`

The compute module provisions tenant resources:

- VMs from a cloud image with cloud-init;
- VMs installed from an ISO (OPNsense, appliances);
- VMs cloned from a golden VM;
- LXC containers.

It consumes foundation and networking outputs and does not read upstream state.

## Inputs

| Name | Type | Required | Description |
|---|---|---|---|
| `vnets` | `map(string)` | no (`{}`) | Networking `vnets` output |
| `bridges` | `map(string)` | no (`{}`) | Foundation `bridges` output |
| `os_images` | `map(string)` | no (`{}`) | Foundation `os_images` output |
| `lxc_templates` | `map(string)` | no (`{}`) | Foundation `lxc_templates` output |
| `cloud_init_templates_dir` | `string` | no (`null`) | Client-owned template directory |
| `virtual_machines` | `map(object)` | yes | VM definitions |
| `containers` | `map(object)` | no (`{}`) | LXC definitions |
| `extra_bridges` | `list(string)` | no (`[]`) | Unmanaged bridges such as `vmbr0` |
| `storage_roles` | `map(object)` | no (`{}`) | Storage roles resolved per node |

Provider settings are not module inputs. They are configured by the caller.

## Outputs

| Name | Description |
|---|---|
| `vm_ids` | VM name -> VM id |
| `vm_vmid` | VM name -> numeric VMID |
| `vm_ipv4_addresses` | VM name -> IPv4 addresses reported by the QEMU agent |
| `container_ids` | Container name -> container id |
| `vnet_catalog` | Input vnet catalog |
| `image_catalog` | Input image catalog |

## VM modes

### Cloud-init

```hcl
"bastion-01" = {
  target_node = "pve"
  os_image    = "ubuntu-2404-cloudinit"
  cores       = 2
  cpu_type    = "x86-64-v2-AES"
  memory      = 2048
  cloud_init = {
    snippet_datastore = "snippets"
    init_datastore    = "images"
    template_file     = "ubuntu-bastion.yaml.tftpl"
    ssh_keys          = ["ssh-ed25519 AAAA... user@example"]
  }
  interfaces = {
    "net0" = { vnet = "DMZ", ip = "10.0.21.5/24", gw = "10.0.21.1" }
  }
  disks = {
    "scsi0" = { storage = "images", size = 20 }
  }
}
```

The first disk receives the downloaded cloud image. The cloud-init snippet is
rendered from `cloud_init_templates_dir`; see
[cloud-init.md](../cloud-init.md).

### ISO / appliance

```hcl
"opnsense-01" = {
  target_node = "pve"
  iso_image   = "opnsense"
  cores       = 4
  cpu_type    = "host"
  memory      = 4096
  serial      = true
  boot_order  = ["ide3", "scsi0"]
  interfaces  = { "net0" = { vnet = "vmbr0", ip = "dhcp" } }
  disks       = { "scsi0" = { storage = "images", size = 30 } }
}
```

ISO installation remains manual in the Proxmox console. `cdrom` is ignored for
drift detection, so the ISO can be removed after installation without
recreating the VM.

### Golden clone

```hcl
"appliance-01" = {
  target_node = "pve"
  clone_from  = 9000
  vm_id       = 220
  interfaces  = { "net0" = { vnet = "DMZ" } }
}
```

`clone_from` cannot be combined with `os_image`, `iso_image` or `cloud_init`.
CPU and memory fields inherit the golden VM unless explicitly set. See
[golden-vm.md](../golden-vm.md).

## Containers

```hcl
"proxy-01" = {
  target_node = "pve"
  template    = "alpine-3-20"
  os_type     = "alpine"
  cores       = 1
  memory      = 512
  interfaces  = { "eth0" = { vnet = "DMZ", ip = "10.0.21.20/24", gw = "10.0.21.1" } }
  disks       = { "rootfs" = { storage = "rootdir", size = 10 } }
}
```

## Validation

`check` blocks validate that every referenced vnet, bridge, image and LXC
template exists in the inputs. Invalid SSH public keys are rejected at plan time
by variable validation.

## Storage resolution

Disk, snippet and container rootfs datastores accept either a real datastore ID
or a storage role. Roles are resolved against the datastores discovered on each
node. See [storage.md](../storage.md).

## Example

```shell
# Apply the foundation and networking examples first.
cd examples/test-local
cp terraform.tfvars.example terraform.tfvars
tofu init
tofu plan
```

## Related documentation

- [Capabilities: compute](../capabilities.md#03-compute)
- [Cloud-init templates](../cloud-init.md)
- [Golden VMs](../golden-vm.md)
- [Pitfalls](../pitfalls.md)
