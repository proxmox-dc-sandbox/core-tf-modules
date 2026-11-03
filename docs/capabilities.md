# Capabilities

Capability matrix of the modules, organized by layer. Detailed input/output
references are in the module documents.

## Design capabilities

| Capability | Details |
|---|---|
| Three-layer architecture | `01-foundation`, `02-networking`, `03-compute`, each with its own state |
| Reduced blast radius | A compute change cannot alter network or underlay resources |
| Explicit contracts | Upstream values are passed as input variables through Terragrunt dependencies |
| Apply order | `01-foundation` -> `02-networking` -> `03-compute`, enforced by `dependency` blocks |
| Reusable modules | Base modules plus `modules/proxmox-vm`, `sdn-zone`, `sdn-vnet`, `storage-resolution` |
| Client-owned configuration | State backend, provider configuration, credentials and cloud-init templates |
| Immutable consumption | Client units pin a Git tag (`?ref=vX.Y.Z`) |
| Validation | Variable validation and `check` blocks for cross-module references |
| Docker runner | OpenTofu + Terragrunt image, with HTTP(S)/SOCKS5 proxy support |
| Multi-environment | One client Terragrunt project per environment, no hidden state reads |

## 01-foundation

### Linux bridges

| Capability | Field |
|---|---|
| Create bridges on a node (`vmbrX`) | `linux_bridges`, key = bridge name |
| IPv4 / IPv6 address | `address`, `address6` |
| Comment and MTU | `comment`, `mtu` |
| Physical ports | `ports` |
| VLAN-aware bridge and allowed VLANs | `vlan_aware`, `vids` |
| Manual comment edits do not recreate the bridge | `ignore_changes = [comment]` |

### SDN zones

| Capability | Field |
|---|---|
| Simple zones (isolated per-node bridges) | `type = "simple"` (default) |
| VLAN zones on an existing bridge | `type = "vlan"`, `bridge` |
| QinQ zones (VLAN stacking) | `type = "qinq"`, `bridge`, `service_vlan`, `service_vlan_protocol` |
| VXLAN overlay zones | `type = "vxlan"`, `peers` |
| EVPN L3 zones | `type = "evpn"`, `controller`, `vrf_vxlan` |
| MTU | `mtu` (576-9000) |
| Node membership | `nodes` |
| IPAM integration | `ipam` |
| DNS zone settings | `dns`, `dns_zone`, `reverse_dns` |
| DHCP backend | `dhcp` (simple zones) |
| EVPN options | `advertise_subnets`, `disable_arp_nd_suppression`, `exit_nodes`, `exit_nodes_local_routing`, `primary_exit_node`, `rt_import` |
| Per-type validation | Required fields checked at plan time |
| Flat zone output | `zones` merges all zone types |

### Images, templates and storage

| Capability | Field |
|---|---|
| Download cloud images and ISOs | `os_images` |
| Content type (`iso` / `import`) | `content_type` |
| Checksum verification | `checksum`, `checksum_algorithm` |
| Download LXC templates | `lxc_templates` |
| Storage selection by name or role | `storage_roles` |
| Create storages | `storages` (`directory`, `nfs`, `lvm`, `lvmthin`, `zfspool`) |
| Inspect datastore capabilities | outputs `datastore_catalog`, `storage_roles` |

## 02-networking

### Vnets

| Capability | Field |
|---|---|
| Attach a vnet to a foundation zone | `sdn_vnets`, `zone` |
| Validate zone references | `zones` input + `check` block |
| VLAN-aware vnet | `vlan_aware` |
| Alias | `alias` |
| Port isolation | `isolate_ports` |
| VLAN tag / VXLAN ID | `tag` (1-4094) |

### Subnets

| Capability | Field |
|---|---|
| Attach subnets to vnets | `sdn_subnets` |
| CIDR and gateway | `cidr`, `gateway` |
| SNAT | `snat` |
| DHCP range | `dhcp_range` |
| DHCP DNS server | `dhcp_dns_server` |
| DNS zone delegation | `dns_zone_prefix` |

### SDN apply

| Capability | Details |
|---|---|
| Apply SDN configuration | `proxmox_sdn_applier` after vnets and subnets |
| Re-apply on changes | `null_resource` fingerprint replaces the applier |
| No duplicated resources | Zones belong to foundation; vnets/subnets to networking |

## 03-compute

### VM modes

| Capability | Field |
|---|---|
| Cloud-init Linux VMs | `os_image` + `cloud_init` |
| ISO / appliance VMs | `iso_image`, `boot_order` |
| Golden-image clones | `clone_from` |
| Automatic cloud image import on `scsi0` | `os_image` resolved from foundation |
| Removable ISO without recreation | `ignore_changes = [cdrom]` |
| Manual ISO installation | Proxmox console |

### Compute configuration

| Capability | Field |
|---|---|
| CPU cores / sockets | `cores`, `sockets` |
| CPU type | `cpu_type` |
| NUMA and CPU flags | `numa`, `cpu_flags` |
| Memory and balloon | `memory`, `memory_shared` |
| QEMU agent | `agent` |
| Serial console | `serial` |
| BIOS and machine type | `bios`, `machine` |
| Fixed VMID | `vm_id` |
| Name, description, tags | map key, `description`, `tags` |
| Boot and start behaviour | `on_boot`, `started` |

### Disks and networking

| Capability | Field |
|---|---|
| Multiple disks | `disks`, key = interface (`scsi0`, `virtio1`, ...) |
| Datastore and size | `storage`, `size` |
| Discard, SSD, iothread, cache | `discard`, `ssd`, `iothread`, `cache` |
| Multiple NICs | `interfaces` map |
| Vnet or bridge by name | `vnet`, `extra_bridges` |
| VLAN tag | `vlan` |
| Static IPv4 or DHCP | `ip`, `gw` |
| Static IPv6, DHCP or auto | `ipv6`, `gw6` |
| NIC model, firewall, MAC | `model`, `firewall`, `mac_address` |
| DNS servers via cloud-init | `cloud_init.dns_servers` |

### Cloud-init and containers

| Capability | Field |
|---|---|
| Client-owned templates | `cloud_init_templates_dir` |
| SSH keys | `cloud_init.ssh_keys` |
| Extra template variables | `cloud_init.template_vars` (`map(string)`) |
| Snippet and init ISO datastores | `snippet_datastore`, `init_datastore` |
| LXC containers | `containers` |
| OS type | `os_type` |
| Unprivileged containers | `unprivileged` |
| Container SSH keys | `ssh_keys` |
| Container interfaces | `interfaces` |
| Container rootfs | `disks.rootfs` |

## Guardrails and safety

| Guardrail | Details |
|---|---|
| Reference validation | `check` blocks for zones, vnets, bridges, images and templates |
| Input validation | Boot source, clone exclusivity, SSH key format, SDN IDs |
| No hidden state reads | Modules only consume explicit inputs |
| No credentials in modules | Provider configuration is generated client-side |
| Ignored drift where needed | Bridge comment, cloud-init initialization, ISO cdrom |
| Deterministic SDN apply | Applier replaced when zone/vnet/subnet fingerprints change |

## Known limitations

| Limitation | Workaround |
|---|---|
| `dhcp_range` read from `for_each` can be rejected as unknown by `bpg/proxmox` | Two subnet resources, rebuilding the object field-by-field |
| `proxmox_sdn_applier` only runs on create/destroy | `null_resource` trigger and `replace_triggered_by` |
| ISO installation is interactive | Install manually in the Proxmox console, or build a golden VM |
| `path.root` points to the Terragrunt cache | Use `cloud_init_templates_dir` with `get_terragrunt_dir()` |
| Provider SSH address can be resolved from the API | Configure the node address in the client provider block or use `node_address_source = "dns"` |
| SDN IDs are restricted | Alphanumeric, max 8 characters, no `-` or `_` |
| Golden clones inherit the golden VM IP | Use DHCP on the golden VM or reconfigure clones |

## Extending the project

- **New VM profile:** add an entry to `virtual_machines`; no code change.
- **New zone, vnet or subnet:** extend the corresponding input; all resources
  are `for_each`-driven.
- **New cloud-init template:** add it to the client project and reference it by
  file name.
- **New storage backend:** add a resource in `01-foundation` and document the
  content types it supports.
- **New module version:** tag the repository, update the client `?ref=`, run
  `terragrunt run --all plan`, then apply.
