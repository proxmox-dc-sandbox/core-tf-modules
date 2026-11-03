# sdn-vnet

Proxmox SDN vnets (and their subnets) attached to a zone. Consumed by
`02-networking`; usable standalone from any client project.

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `vnets` | `map(object)` | — | Vnets to manage. Key = vnet id. Each object: `zone` (must be an existing zone id), `vlan_aware`, `tag`, plus per-object subnets (`cidr`, `gateway`, `snat`, `dhcp_dns_server`, `dhcp_range`). See `variables.tf` for the full object contract. |

## Outputs

| Name | Description |
|------|-------------|
| `vnets` | Vnet id -> vnet id (flat map for the callers' dependencies). |
| `vnet_details` | Full vnet resources (id, state, pending). |

## Usage

Called by `02-networking` with the vnet catalogue; zones come from the
`sdn-zone` module (via the foundation layer). The applier triggers on the
`zones_config` fingerprint so a zone change re-applies the SDN. Full
example: `02-networking/examples/test-local`.

## Compatibility

- OpenTofu `>= 1.8.0`, provider `bpg/proxmox` (see the root README
  "Provider compatibility").
- No provider configuration and no backend here: the client project owns
  them.
