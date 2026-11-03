# sdn-zone

Proxmox SDN zones — one resource per zone type (`simple`, `vlan`, `qinq`,
`vxlan`, `evpn`), all exposing the same id so downstream layers only see a
flat map of zone ids. Consumed by `01-foundation`; usable standalone.

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `zones` | `map(object)` | — | Zones to manage. Key = zone id. `type` selects the model: `simple` (per-node isolated bridge, optional `dhcp`), `vlan`/`qinq` (`bridge`, VLAN fields), `vxlan` (`peers`), `evpn` (`controller`, `vrf_vxlan`, exit nodes — see `01-foundation`'s `sdn_controllers`). Common fields: `nodes`, `mtu`, `ipam`, `dns`. See `variables.tf` for the full object contract. |

## Outputs

| Name | Description |
|------|-------------|
| `zones` | Zone id -> zone id (flat map for the callers' dependencies). |
| `zone_details` | Full zone resources per type (id, state, pending). |
| `zones_config` | JSON fingerprint of the zone definitions — the networking module keys its SDN re-apply on this value. |

## Usage

Called by `01-foundation` with the zone catalogue. The destroy order
matters for EVPN zones (a zone must be gone before its controller), which
is why client projects own the zone in a unit ordered before the
foundation destroy. Full example: `01-foundation/examples/test-local`.

## Compatibility

- OpenTofu `>= 1.8.0`, provider `bpg/proxmox` (see the root README
  "Provider compatibility").
- No provider configuration and no backend here: the client project owns
  them.
