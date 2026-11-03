# Module `02-networking`

The networking module provisions the SDN overlay:

- SDN vnets attached to foundation zones;
- subnets, optional DHCP ranges and DNS settings;
- the SDN apply operation.

It consumes foundation outputs and does not read upstream state.

## Inputs

| Name | Type | Required | Description |
|---|---|---|---|
| `zones` | `map(string)` | yes | Foundation `zones` output; validates vnet references |
| `zones_config` | `string` | no (`"{}"`) | Foundation `zones_config` fingerprint |
| `controllers_config` | `string` | no (`"{}"`) | Foundation `controllers_config` fingerprint |
| `sdn_vnets` | `map(object)` | yes | Vnets to create |
| `sdn_subnets` | `map(object)` | yes | Subnets to attach to the vnets |

Provider settings are not module inputs. They are configured by the caller.

## Outputs

| Name | Description |
|---|---|
| `vnets` | Map of vnet id -> vnet id |
| `subnets` | Map of subnet key -> CIDR |
| `zones` | Pass-through of the input zones |

## Behaviour

### Zone validation

A `check` block fails when a vnet references a zone that is absent from the
`zones` input. This catches a missing or stale foundation unit before any
network resource is created.

### Subnets and DHCP

Subnets are created with `proxmox_sdn_subnet`. Because of a provider bug in the
`bpg/proxmox` provider (an object read from a `for_each` value can be rejected as
"unknown"), the module uses two resources:

- `subnets` for subnets without `dhcp_range`;
- `subnets_dhcp` for subnets with a `dhcp_range`, rebuilding the object
  field-by-field.

See [pitfalls.md](../pitfalls.md#dhcp-range-seen-as-unknown-with-for_each) for
details.

### SDN apply

`proxmox_sdn_applier` only runs on create/destroy. A `null_resource` fingerprint
triggers its replacement when zones, controllers, vnets or subnets change.

## Example

```shell
# Apply the foundation example first.
cd examples/test-local
cp terraform.tfvars.example terraform.tfvars
tofu init
tofu plan
```

The example reads the foundation example state and passes its outputs to this
module.

## Related documentation

- [Capabilities: networking](../capabilities.md#02-networking)
- [Pitfalls](../pitfalls.md)
- [DHCP recipe](../pitfalls.md#sdn-dhcp)
