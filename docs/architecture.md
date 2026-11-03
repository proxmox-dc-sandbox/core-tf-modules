# Architecture

The project provisions a Proxmox VE datacenter through three independently
applied layers. This document describes the boundaries, contracts and data flow
between them.

## Layer model

```
+----------------+       +----------------+       +----------------+
| 01-foundation  |  -->  | 02-networking  |  -->  |  03-compute    |
| underlay       |       | overlay        |       | tenants        |
+----------------+       +----------------+       +----------------+
        |                        |                        |
        +---- outputs -----------+---- outputs -----------+
                 explicit input variables (Terragrunt dependency)
```

Each layer is a separate OpenTofu module with its own state in the client
project. There is no hidden state read inside the modules: every upstream value
is an input variable.

| Layer | Owns | Does not own |
|---|---|---|
| `01-foundation` | Bridges, SDN zones and controllers, image/template downloads, storage creation, storage role resolution | Vnets, subnets, guests |
| `02-networking` | SDN vnets, subnets, SDN apply | Zones, bridges, guests |
| `03-compute` | VMs, LXC containers | Any network or storage object |

## Module contracts

### 01-foundation

Inputs:

| Input | Type | Description |
|---|---|---|
| `linux_bridges` | `map(object)` | Linux bridges (`vmbrX`) to create |
| `sdn_zones` | `map(object)` | SDN zones (`simple`, `vlan`, `qinq`, `vxlan`, `evpn`) |
| `sdn_controllers` | `map(object)` | EVPN controllers |
| `os_images` | `map(object)` | Cloud images and ISOs to download |
| `lxc_templates` | `map(object)` | LXC templates to download |
| `storage_roles` | `map(object)` | Logical storage roles resolved by content type |
| `storages` | `map(object)` | Optional storage creation (`directory`, `nfs`, `lvm`, `lvmthin`, `zfspool`) |

Outputs:

| Output | Consumed by | Description |
|---|---|---|
| `zones` | `02-networking` | Flat map of zone id -> zone id |
| `zones_config` | `02-networking` | Fingerprint that triggers an SDN re-apply |
| `controllers_config` | `02-networking` | Controller fingerprint |
| `bridges` | `03-compute` | Bridge name -> bridge id |
| `os_images` | `03-compute` | Image key -> file id |
| `lxc_templates` | `03-compute` | Template key -> file id |
| `storage_roles` | diagnostics | Node -> role -> resolved datastore |
| `datastore_catalog` | diagnostics | Node -> datastore -> content types |

### 02-networking

Inputs:

| Input | Type | Description |
|---|---|---|
| `zones` | `map(string)` | Foundation `zones` output; used to validate vnet references |
| `zones_config` | `string` | Foundation fingerprint |
| `controllers_config` | `string` | Foundation fingerprint |
| `sdn_vnets` | `map(object)` | Vnets to create |
| `sdn_subnets` | `map(object)` | Subnets and optional DHCP ranges |

Outputs:

| Output | Consumed by | Description |
|---|---|---|
| `vnets` | `03-compute` | Vnet id -> vnet id |
| `subnets` | diagnostics | Subnet key -> CIDR |
| `zones` | diagnostics | Pass-through of the input zones |

The module includes a `check` block that fails when a vnet references a zone
that is absent from `zones`.

### 03-compute

Inputs:

| Input | Type | Description |
|---|---|---|
| `vnets` | `map(string)` | Networking `vnets` output |
| `bridges` | `map(string)` | Foundation `bridges` output |
| `os_images` | `map(string)` | Foundation `os_images` output |
| `lxc_templates` | `map(string)` | Foundation `lxc_templates` output |
| `cloud_init_templates_dir` | `string` | Client-owned cloud-init template directory |
| `virtual_machines` | `map(object)` | VM definitions |
| `containers` | `map(object)` | LXC definitions (default `{}`) |
| `extra_bridges` | `list(string)` | Unmanaged bridges such as `vmbr0` |
| `storage_roles` | `map(object)` | Storage roles resolved per node |

Outputs:

| Output | Description |
|---|---|
| `vm_ids` | VM name -> VM id |
| `vm_vmid` | VM name -> numeric VMID |
| `vm_ipv4_addresses` | VM name -> IPv4 addresses reported by the QEMU agent |
| `container_ids` | Container name -> container id |
| `vnet_catalog` | Input vnet catalog (tooling) |
| `image_catalog` | Input image catalog (tooling) |

`check` blocks validate network, image and template references before apply.

Per-module references:
[01-foundation](modules/01-foundation.md),
[02-networking](modules/02-networking.md),
[03-compute](modules/03-compute.md).

## Shared building blocks

The base modules compose smaller modules from `modules/`:

| Module | Used by | Responsibility |
|---|---|---|
| `modules/sdn-zone` | `01-foundation` | One resource per SDN zone type |
| `modules/storage-resolution` | `01-foundation`, `03-compute` | Resolve storage roles and (node, ref) pairs from content types |
| `modules/sdn-vnet` | `02-networking` | SDN vnets |
| `modules/proxmox-vm` | `03-compute` | VMs: cloud-init, ISO or clone, disks, NICs |

These modules have no backend and no provider configuration either. They are
internal to the repository and not part of the client contract.

## Data flow in a client project

Terragrunt wires the layers with `dependency` blocks:

```hcl
# 02-networking/terragrunt.hcl
dependency "foundation" {
  config_path = "../01-foundation"
}

inputs = {
  zones              = dependency.foundation.outputs.zones
  zones_config       = dependency.foundation.outputs.zones_config
  controllers_config = dependency.foundation.outputs.controllers_config
}
```

```hcl
# 03-compute/terragrunt.hcl
dependency "foundation" {
  config_path = "../01-foundation"
}

dependency "networking" {
  config_path = "../02-networking"
}

inputs = {
  vnets         = dependency.networking.outputs.vnets
  bridges       = dependency.foundation.outputs.bridges
  os_images     = dependency.foundation.outputs.os_images
  lxc_templates = dependency.foundation.outputs.lxc_templates
}
```

This makes the apply order explicit and allows `terragrunt run --all` to plan
and apply in dependency order.

## State model

- The modules contain **no backend block**. The state backend is generated by
  the client project (Terragrunt `remote_state`).
- The modules contain **no provider configuration**. The provider block is
  generated by the client project (Terragrunt `generate`).
- The development examples have their own local provider and local backend; they
  are never used by clients.
- Each Terragrunt unit gets its own state. Upstream values are exchanged through
  outputs/dependencies, not by reading another unit's state from inside a module.

## Versioning model

The repository is a module source, not a deployed environment. Releases are Git
tags: `v1.0.0`, `v1.1.0`, `v2.0.0`. Client units reference a tag explicitly and
upgrade on purpose. Breaking changes to module inputs or outputs require a major
version bump.

## Design constraints

- **No backend in modules.** A module must work with any client backend.
- **No credentials in modules.** Authentication belongs to the caller.
- **No `terraform_remote_state` in modules.** Dependencies are explicit inputs.
- **No cloud-init templates in modules.** Templates are client-owned for
  portability; development copies live in `03-compute/examples/test-local`.
- **Names, not opaque IDs.** Client configuration references vnets, bridges and
  images by logical name; modules resolve them through input catalogs.
