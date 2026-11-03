# Pitfalls and troubleshooting

Lessons learned while developing and validating the modules with OpenTofu, the
`bpg/proxmox` provider and Proxmox VE. Each entry follows the same structure:
symptom, cause, solution.

## Node prerequisites

### Storage content types

**Symptom:** `the datastore "local" does not support content type "snippets"`.

**Cause:** each datastore only accepts the content types enabled in its
configuration. Common requirements:

- cloud-init snippets -> `snippets`
- VM disks -> `images`
- container rootfs -> `rootdir`
- ISOs and cloud images -> `iso` (`import` for qcow2)
- LXC templates -> `vztmpl`

**Solution:** enable the content types in the Proxmox UI (Datacenter -> Storage
-> Content), create the storage through `storages` in `01-foundation`, or use
[storage roles](storage.md).

### Missing `dnsmasq` package

**Symptom:** `please install the 'dnsmasq' package in order to use the DHCP
feature!` and no DHCP server starts.

**Cause:** the Proxmox SDN DHCP plugin uses dnsmasq; the package is not always
installed.

**Solution:**

```shell
apt-get install dnsmasq
systemctl disable --now dnsmasq   # Proxmox manages it through pvedaemon
```

Then re-apply the SDN configuration.

### Proxmox 9.2 dnsmasq uses static reservations

**Symptom:** generated files under `/etc/dnsmasq.d/<zone>/` contain
`dhcp-range=...,static,...` even when `dhcp_range` is configured; no dynamic
lease is served.

**Cause:** in Proxmox 9.2 the SDN dnsmasq plugin always writes `static`. The
subnet `dhcp_range` is used by the built-in IPAM, which allocates an address at
guest creation and registers it in `/etc/dnsmasq.d/<zone>/ethers`. dnsmasq
serves these reservations.

**Solution:** configure the zone with both `dhcp = "dnsmasq"` and
`ipam = "pve"`. Verify with:

```shell
cat /etc/dnsmasq.d/<zone>/ethers
cat /var/lib/misc/dnsmasq.<zone>.leases
```

### `ipam` cannot be changed while subnets exist

**Symptom:** `can't change ipam if a subnet is already defined in this zone`.

**Cause:** Proxmox forbids changing the IPAM backend of a zone that already has
subnets.

**Solution:** destroy `02-networking` first, change the zone in
`01-foundation`, then re-apply in order.

### Download URLs must be reachable from the node

**Symptom:** `proxmox_download_file` fails or the image never appears.

**Cause:** downloads run on the Proxmox node, not on the machine running
OpenTofu.

**Solution:** test the URL from the node:

```shell
curl -sI <url>
```

## Provider `bpg/proxmox`

### DHCP range seen as unknown with `for_each`

**Symptom:** `Received unknown value, however the target type cannot handle
unknown values. Path: dhcp_range`.

**Cause:** a provider bug: an object (`dhcp_range`) read directly from a
`for_each` value can be marked unknown and rejected by its custom type. A
ternary with a `null` branch can also trigger it.

**Solution:** rebuild the object field-by-field without a ternary and split the
resources:

```hcl
resource "proxmox_sdn_subnet" "subnets" {
  for_each = { for k, v in var.sdn_subnets : k => v if v.dhcp_range == null }
  # ...
}

resource "proxmox_sdn_subnet" "subnets_dhcp" {
  for_each = { for k, v in var.sdn_subnets : k => v if v.dhcp_range != null }
  # ...
  dhcp_range = {
    start_address = each.value.dhcp_range.start_address
    end_address   = each.value.dhcp_range.end_address
  }
}
```

### `proxmox_sdn_applier` only runs on create/destroy

**Symptom:** changing a zone, vnet or subnet does not regenerate the applied SDN
configuration.

**Cause:** the applier resource has no update operation.

**Solution:** a `null_resource` with fingerprints and
`lifecycle { replace_triggered_by = [null_resource.sdn_trigger] }` on the
applier. This is implemented in `02-networking`.

### Deprecated datastores data source

**Symptom:** `Warning: Deprecated ... Use "proxmox_datastores" instead`.

**Solution:** use `data "proxmox_datastores"`; the old
`proxmox_virtual_environment_datastores` is being removed.

### Adopting an existing storage is refused

**Symptom:** `storage ID 'local' already defined` when `storages` contains an
existing storage.

**Cause:** `proxmox_storage_*` resources only create storages.

**Solution:** import the storage once:

```shell
tofu import 'proxmox_storage_directory.this["local"]' local
```

Do not remove an imported storage from the configuration without a `state rm`;
OpenTofu would destroy the real storage.

### `nodes` not reported for local storages

**Symptom:** perpetual diff on `nodes`.

**Solution:** `lifecycle { ignore_changes = [nodes] }` on the storage
resources, as implemented in `01-foundation`.

### Provider resolves the SSH node address from the API

**Symptom:** the provider dials an internal cluster IP for SSH even though the
node address is configured explicitly.

**Cause:** the default `node_address_source = "api"` uses the address reported
by the Proxmox API, which may be unreachable from the runner.

**Solution:** use `node_address_source = "dns"` in the generated provider and
provide a hosts entry for the node name, or configure the correct node address
in the client provider block.

### SSH behind a SOCKS5 proxy

**Symptom:** `dial tcp <ip>:22: i/o timeout` while the API works through
`HTTP_PROXY` / `HTTPS_PROXY`.

**Cause:** HTTP(S) proxy variables do not cover the provider's SSH connections.

**Solution:** set the dedicated SOCKS5 option:

```shell
docker run -e PROXMOX_VE_SSH_SOCKS5_SERVER="proxy.example.com:1080" ...
```

Or configure `ssh.socks5_server` in the client provider block, with optional
`socks5_username` / `socks5_password`.

## Modules and OpenTofu

### Snippet and cloud-init ISO need different datastores

**Symptom:** `storage 'local' does not support content-type 'images'` when the
VM starts.

**Cause:** the snippet needs `snippets`, while the cloud-init ISO generated by
Proxmox needs `images`.

**Solution:** use `cloud_init.snippet_datastore` for the snippet and
`cloud_init.init_datastore` for the ISO. The latter defaults to the former when
omitted.

### Duplicate `required_providers` configuration with Terragrunt

**Symptom:** `A module may have only one required providers configuration`.

**Cause:** the Terragrunt `generate "provider"` block writes a
`terraform { required_providers { ... } }` block into the module directory,
while the module source already declares `required_providers` in its
`versions.tf`. Both end up in the same root module.

**Solution:** generate only the provider configuration block. Provider
requirements and versions are declared by the module source:

```hcl
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "proxmox" {
      # endpoint/token come from the environment
    }
  EOF
}
```

### Upstream outputs are not yet in state

**Symptom:** `This object does not have an attribute named "<output>"` in a
Terragrunt dependency.

**Cause:** an output added to a module does not exist in the upstream unit's
state until that unit is applied.

**Solution:** apply the upstream unit first:

```shell
terragrunt --working-dir 01-foundation apply
```

For examples, apply `01-foundation/examples/test-local` before
`02-networking/examples/test-local`, and so on.

### HCL pitfalls

- Two consecutive `for` expressions in a single `flatten([...])` are invalid;
  nest them in sub-lists.
- Avoid regex replacements for multi-line HCL blocks; use unique anchors or a
  real parser.

## Guests

### Placeholder SSH keys

**Symptom:** HTTP 500 `SSH public key validation error`.

**Cause:** invalid placeholder keys such as `ssh-rsa AAAA...PLACEHOLDER`.

**Solution:** use a real public key. `03-compute` validates the format at plan
time and returns a clear error.

### sshd missing from Alpine templates

**Symptom:** `Connection refused` on port 22 for a fresh Alpine container.

**Cause:** the default Alpine LXC template does not enable sshd.

**Solution:**

```shell
pct exec <vmid> -- sh -c "apk add openssh; rc-update add sshd default; rc-service sshd start"
```

This is not persisted by OpenTofu; repeat it after recreating the container.

### fail2ban bans the node IP

**Symptom:** SSH is refused after repeated attempts on a TurnKey template.

**Cause:** fail2ban is active in the template and the node IP is banned.

**Solution:**

```shell
pct exec <vmid> -- fail2ban-client set sshd unbanip <ip>
# or flush the rule:
pct exec <vmid> -- iptables -F f2b-SSH
```

### QEMU agent disabled

**Symptom:** `vm_ipv4_addresses` is empty.

**Cause:** `agent = false` or the guest does not run the QEMU guest agent.

**Solution:** set `agent = true` and install the agent in the guest image.

### SDN identifiers are restricted

**Symptom:** `Attribute id must be a valid SDN identifier`.

**Cause:** SDN IDs must match `^[A-Za-z][A-Za-z0-9]*[A-Za-z0-9]$`, be at most
8 characters and contain no `-` or `_`.

**Solution:** use short alphanumeric identifiers such as `dmz`, `frr1` or
`lab1`.

## SDN DHCP

A guest can obtain its address over DHCP when three conditions are met.

1. **Zone** (`01-foundation`): `dhcp = "dnsmasq"` and `ipam = "pve"`.
2. **Subnet** (`02-networking`): a `dhcp_range` inside the subnet CIDR, and
   optionally `dhcp_dns_server`.
3. **Guest** (`03-compute`): omit `ip` and `gw` on the interface; the provider
   configures DHCP.

Verification on the node:

```shell
cat /etc/dnsmasq.d/<zone>/ethers
cat /var/lib/misc/dnsmasq.<zone>.leases
```

Notes:

- install the `dnsmasq` package on the node;
- recreate a zone before changing its `ipam` if subnets already exist;
- on Proxmox versions that always generate static dnsmasq reservations, the
  IPAM allocates the address at guest creation.

## Security hygiene

- Never commit private keys (`id_rsa`, `*.pem`), state files or local variable
  files.
- API tokens belong in environment variables or an external secret manager.
- Check `git status` before committing.
- Public SSH keys are not sensitive; private keys must never be committed.

## See also

- [Capabilities and known limitations](capabilities.md)
- [Storage guide](storage.md)
- [EVPN routing case study](case-studies/evpn-routing.md)
