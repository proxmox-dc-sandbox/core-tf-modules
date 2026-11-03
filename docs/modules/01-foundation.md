# Module `01-foundation`

The foundation module provisions the datacenter underlay and global objects:

- Linux bridges (`vmbrX`);
- SDN zones and EVPN controllers;
- OS images (cloud images and ISOs) and LXC templates;
- storage creation and storage-role resolution.

It is the first layer of the stack. It does not consume any upstream output.

## Inputs

| Name | Type | Required | Description |
|---|---|---|---|
| `linux_bridges` | `map(object)` | no (`{}`) | Linux bridges to create on the nodes |
| `sdn_zones` | `map(object)` | yes | SDN zones (`simple`, `vlan`, `qinq`, `vxlan`, `evpn`) |
| `sdn_controllers` | `map(object)` | no (`{}`) | EVPN controllers referenced by `evpn` zones |
| `os_images` | `map(object)` | yes | Cloud images and ISOs to download |
| `lxc_templates` | `map(object)` | no (`{}`) | LXC templates to download |
| `storage_roles` | `map(object)` | no (`{}`) | Logical roles resolved from datastore content types |
| `storages` | `map(object)` | no (`{}`) | Optional storage creation |

Provider settings are not module inputs. They are configured by the caller
(Terragrunt `root.hcl` or `examples/test-local/provider.tf`).

## Outputs

| Name | Description |
|---|---|
| `zones` | Map of zone id -> zone id |
| `zones_config` | JSON fingerprint of `sdn_zones` |
| `controllers` | Map of controller id -> controller id |
| `controllers_config` | JSON fingerprint of `sdn_controllers` |
| `bridges` | Map of bridge name -> bridge id |
| `os_images` | Map of image key -> file id |
| `lxc_templates` | Map of template key -> file id |
| `datastore_catalog` | Node -> datastore -> content types |
| `storage_roles` | Node -> role -> resolved datastore |

## Behaviour

### Bridges

Bridges are created with `proxmox_network_linux_bridge`. The `comment` field is
ignored for drift detection so a manual edit does not recreate the bridge.

### Zones and controllers

Zones are delegated to [`modules/sdn-zone`](../../modules/sdn-zone). A `check` block
fails when an `evpn` zone references a controller that is not declared in
`sdn_controllers`.

### Images and templates

Images and templates are downloaded with `proxmox_download_file`. The
`datastore` field accepts either a real datastore ID or a storage role name. A
`check` block fails with an explicit message when a reference cannot be resolved.

### Storage roles

Storage roles are resolved per node by [`modules/storage-resolution`](../../modules/storage-resolution).
A role maps to the content types it requires (`iso`, `vztmpl`, `snippets`,
`images`, `rootdir`, ...). The first matching datastore is selected unless the
role pins one with `datastore = "..."`.

See [storage.md](../storage.md) for the complete guide.

## Example

```shell
cd examples/test-local
cp terraform.tfvars.example terraform.tfvars
tofu init
tofu plan
```

The example calls this module from `../..` and owns its provider and local
backend.

## Related documentation

- [Capabilities: foundation](../capabilities.md#01-foundation)
- [Storage guide](../storage.md)
- [Pitfalls](../pitfalls.md)
