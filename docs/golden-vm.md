# Golden VMs and cloning

Golden VMs automate appliances and ISO-based systems that cannot be provisioned
from cloud-init. Build a reference VM once, keep it powered off, then let
`03-compute` clone it with `clone_from` (`proxmox_cloned_vm` in `bpg/proxmox`).

```
[build once]                                  [reproducible clones]
Packer (automated)                        03-compute
or manual install (VMID 9000)               └─ clone_from = 9000
        |                                        ├─ "dmz-appliance-01" (DMZ)
        v                                        └─ "lab-appliance-01" (LAB)
Golden VM powered off (e.g. 9000)
```

The golden VM contains the OS, network configuration, services and any other
settings. Clones inherit everything and optionally override identity and
network attachments.

## Declaring a clone

In a client project, add an entry to the `virtual_machines` input of the compute
unit:

```hcl
inputs = {
  virtual_machines = {
    "dmz-appliance-01" = {
      target_node = "pve"
      clone_from  = 9000 # golden VMID
      vm_id       = 220  # optional: pin the clone VMID
      started     = true
      interfaces = {
        "net0" = { vnet = "DMZ" } # override the bridge on the clone
      }
      # Do not set os_image, iso_image, cloud_init or disks:
      # everything comes from the golden VM.
    }
  }
}
```

Rules:

- `clone_from` cannot be combined with `os_image`, `iso_image` or
  `cloud_init`.
- `interfaces` and `disks` can be omitted to keep the golden VM configuration.

### Overriding CPU and memory

By default `cores`, `sockets`, `cpu_type`, `numa`, `cpu_flags`, `memory` and
`memory_shared` are `null`: the clone inherits the golden VM. Setting a value
applies it to the clone:

```hcl
"dmz-appliance-01" = {
  target_node = "pve"
  clone_from  = 9000
  cores       = 4
  cpu_type    = "host"
  memory      = 4096
  # memory_shared = 2048
}
```

## Building a golden VM without Packer

1. Create an installation VM on the cluster:

   ```shell
   qm create 9000 --name golden-opnsense --memory 2048 --cores 2 \
     --net0 virtio,bridge=vmbr0 \
     --scsi0 local-lvm:20 \
     --cdrom local:iso/OPNsense-26.7-dvd-amd64.iso \
     --ostype other
   ```

2. Start it (`qm start 9000`) and install the system through the console
   (`qm terminal 9000` or the Proxmox UI).
3. Configure the appliance: hostname, IP, gateway, DNS, services. This is the
   configuration inherited by every clone.
4. Eject the ISO:
   `qm set 9000 --delete cdrom` (or `--ide2 none,media=cdrom`).
5. Shut the VM down: `qm shutdown 9000`.
6. Optionally convert it to a Proxmox template:

   ```shell
   qm template 9000
   ```

7. Keep the golden VM outside OpenTofu management. Do not add it to
   `virtual_machines`; reference it only through `clone_from`.

8. Test a clone by adding a `clone_from` entry to the compute unit and applying
   it.

## Building a golden VM with Packer

See [packer.md](packer.md) for the workflow and prerequisites.

## Operational notes

### Clone IP addresses

Clones inherit the IP configured in the golden VM. To give each clone a
different address:

- configure the golden VM for DHCP on a subnet with an IPAM-managed
  `dhcp_range` (recommended); or
- reconfigure the guest after cloning (vendor-specific configuration).

### QEMU agent

`vm_ipv4_addresses` is empty for clones when the golden VM does not run the
QEMU guest agent. Install and enable it in the golden image if you need address
reporting.

### Full clones

Clones use `clone.full = true`: they do not depend on the golden VM after
cloning. Deleting the golden VM does not affect existing clones.

### Templates

A Proxmox template can be used as `clone_from` just like a powered-off VM.

### VMID ownership

Do not use a `clone_from` VMID that is also managed by OpenTofu. A VMID must be
managed by exactly one system.
