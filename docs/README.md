# Documentation

Project documentation for the Proxmox Datacenter Modules.

## Guides

| Document | Audience | Content |
|---|---|---|
| [architecture.md](architecture.md) | Contributors, client authors | Layer boundaries, contracts, data flow, state model |
| [getting-started.md](getting-started.md) | Contributors | Prerequisites, local examples, first apply |
| [terragrunt.md](terragrunt.md) | Client authors | Client layout, tag pinning, backend/provider generation, upgrades |
| [cloud-init.md](cloud-init.md) | Client authors, contributors | Template ownership, resolution rules, variables |
| [storage.md](storage.md) | Client authors | Datastores, content types, roles, Ceph/NFS examples |
| [docker.md](docker.md) | Contributors, client authors | Runner image, proxies, wrappers, build troubleshooting |
| [golden-vm.md](golden-vm.md) | Client authors | Golden-image VMs, cloning, IP strategy |
| [packer.md](packer.md) | Contributors | Building golden images with Packer |
| [pitfalls.md](pitfalls.md) | Everyone | Provider, SDN, storage and guest troubleshooting |
| [capabilities.md](capabilities.md) | Everyone | Capability matrix and known limitations |
| [migration.md](migration.md) | Existing users | Migration from the legacy repository |

## Module references

| Module | Document |
|---|---|
| `01-foundation` | [modules/01-foundation.md](modules/01-foundation.md) |
| `02-networking` | [modules/02-networking.md](modules/02-networking.md) |
| `03-compute` | [modules/03-compute.md](modules/03-compute.md) |

## Case studies

| Document | Content |
|---|---|
| [case-studies/evpn-routing.md](case-studies/evpn-routing.md) | Debugging guest connectivity on an EVPN zone |
