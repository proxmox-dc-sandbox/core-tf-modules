# Module `02-networking`

Creates the SDN overlay: vnets, subnets and the SDN apply.

## Contract

- No backend and no provider configuration.
- Does not read the foundation state: upstream values are passed as inputs.

## Inputs from foundation

| Input | Source output |
|---|---|
| `zones` | `zones` |
| `zones_config` | `zones_config` |
| `controllers_config` | `controllers_config` |

A `check` block fails with a clear message when a vnet references a zone that
is not present in `zones`.

## Local development

```shell
# Apply the foundation example first.
cd examples/test-local
cp terraform.tfvars.example terraform.tfvars
tofu init
tofu plan
```

The example reads the sibling foundation example state
(`01-foundation/examples/test-local/terraform.tfstate`) and passes its
outputs to this module.

Full input/output reference: [docs/modules/02-networking.md](../docs/modules/02-networking.md).
