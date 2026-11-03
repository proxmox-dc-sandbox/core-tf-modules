# Case study: EVPN guest connectivity

This case study documents a troubleshooting session on an EVPN SDN zone. Values
are sanitized; addresses use documentation ranges.

## Context

| Item | Value |
|---|---|
| Proxmox VE | 9.2, node `pve-01` |
| Access | API and provider SSH through a SOCKS5 proxy |
| SDN zone | `cloud`, type EVPN, controller `frrbgp`, AS 64512, `ipam = "pve"` |
| Vnet / subnet | `pubvm` (tag 15) / `203.0.113.0/24`, gateway `203.0.113.1` |
| Guest | `test-guest` (VMID 100), Ubuntu cloud image, static `203.0.113.26/24` |
| State | one state per layer, propagated as explicit inputs |

## Setup

1. Removed stale SDN objects in order: subnet -> vnet -> zone -> controller.
2. Created the guest with a static address outside the DHCP range and a serial
   console.
3. Disabled SNAT on the EVPN subnet.
4. Cleaned up leftover iptables rules from previous tests.

## Problems encountered

| # | Problem | Cause | Resolution |
|---|---|---|---|
| 1 | `unable to parse directory volume name 'snippets/cloudbox/...'` | The cloud-init snippet path contained a stale subdirectory | Re-applied with a clean snippet path at the root of `snippets/` |
| 2 | `unable to authenticate user root ...` | The provider used a placeholder SSH key that was not authorized on the node | Configured the correct key in the client provider block |
| 3 | Node-to-guest SSH timed out (immediate RST) | EVPN/VRF routing asymmetry: return traffic is handled in the VRF | Expected EVPN behaviour; see below |
| 4 | External SSH through the proxy timed out | The proxy did not route the guest subnet | Added a route on the client side |
| 5 | SNAT left asymmetric return paths | Masquerading broke inbound connections | Disabled SNAT on the routed subnet |

## EVPN behaviour

On an EVPN zone (VRF + FRR/BGP):

- **The node cannot reach its own EVPN guests over TCP.** Return packets are
  processed in the VRF and the kernel emits an immediate RST. ICMP may work
  while TCP does not.
- **Guest-to-guest traffic on the same vnet is L2** through the bridge and
  works normally.
- **External traffic** follows FRR/BGP in both directions and works once the
  client route is in place.
- A guest on an EVPN zone is therefore not reachable from the host by default.
  This is a useful isolation property. Use one of:
  - a relay VM on the same vnet;
  - a BGP router with a route to the subnet;
  - the Proxmox serial console.

## Access options

### Serial console

```shell
qm terminal <vmid>
```

### Routed access

Requirements:

1. a route to the guest subnet through the Proxmox node or a BGP router;
2. SSH access with the authorized key or another configured method.

### Relay VM

A VM attached to the same vnet can reach the guest over L2 without BGP.

## Lessons

- SDN IDs must match `^[A-Za-z][A-Za-z0-9]*[A-Za-z0-9]$`, be at most 8
  characters and contain no `-` or `_`.
- Cloud-init snippets must be referenced at the root of the `snippets/`
  directory, without a subdirectory.
- SNAT on a routed EVPN subnet is unnecessary and can break inbound traffic.
- The provider SSH key must be authorized on the node.
- A serial console is a reliable fallback for guests on isolated networks.
