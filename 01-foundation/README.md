# Module `01-foundation`

Creates the datacenter underlay:

- Linux bridges (`vmbrX`)
- SDN zones (`simple`, `vlan`, `qinq`, `vxlan`, `evpn`) and EVPN controllers
- OS images (cloud images / ISOs) and LXC templates
- Optional storages (`directory`, `nfs`, `lvm`, `lvmthin`, `zfspool`)
- Storage role resolution by content type

## Contract

- No backend: the caller generates it (Terragrunt `remote_state`).
- No provider configuration: only `required_providers` is declared. The caller
  supplies credentials/endpoint/SSH (Terragrunt `generate` or the example).
- No upstream state read: this is the first module.

## Outputs used downstream

- `zones`, `zones_config`, `controllers_config` -> `networking`
- `bridges`, `os_images`, `lxc_templates` -> `compute`
- `storage_roles`, `datastore_catalog` -> diagnostics

## Local development

```shell
cd examples/test-local
cp terraform.tfvars.example terraform.tfvars
tofu init
tofu plan
```

The example calls this module from `../..` and owns a local provider and local
backend (`examples/test-local/provider.tf`, `backend.tf`).

Full input/output reference: [docs/modules/01-foundation.md](../docs/modules/01-foundation.md).
