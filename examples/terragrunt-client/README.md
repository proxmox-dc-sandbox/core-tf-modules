# Terragrunt client example

This folder is a minimal client project consuming the modules from this
repository. It follows the mandatory rules:

- every `terraform.source` points to a **Git tag** (`?ref=v1.0.0-rc1`);
- the state backend is **generated** by `root.hcl` (no backend in the modules);
- the provider is **generated** by `root.hcl` (no provider config in the modules);
- `03-compute/cloud-init-templates/` is owned by this client.

## Layout and apply order

```
root.hcl                        # tag pinning + generated backend/provider
01-foundation/                  # 1. underlay (bridges, zones, images, storages)
02-networking/                  # 2. overlay (vnets, subnets)  -> depends on 01
03-compute/                     # 3. tenants (VMs, LXC)        -> depends on 01+02
03-compute/cloud-init-templates/  # client-owned templates
```

Terragrunt resolves the order through `dependency` blocks:

```
01-foundation -> 02-networking -> 03-compute
```

## Configure

The source uses a placeholder Git remote and is pinned to the immutable tag
`v1.0.0-rc1` in each unit. Replace the URL in the three `terragrunt.hcl` files with
your repository URL. Bump the `?ref=` tag deliberately.

```hcl
terraform {
  source = "git::https://example.com/org/pdcs-core-tf-modules.git//01-foundation?ref=v1.0.0-rc1"
}
```

Provider credentials come from the environment:

```shell
export PROXMOX_VE_ENDPOINT="https://pve.example.com:8006"
export PROXMOX_VE_API_TOKEN='root@pam!token=...'
export PROXMOX_NODE_NAME="pve"
export PROXMOX_NODE_ADDRESS="pve.example.com"
# SSH: agent by default; set PROXMOX_VE_SSH_AGENT=false to use a key file
# configured in root.hcl.
```

Adjust the inputs (node names, storages, images, IPs, SSH keys) in the three
`terragrunt.hcl` files before applying.

## Run

From the repository root:

```shell
./terragrunt-docker.sh examples/terragrunt-client run --all validate
./terragrunt-docker.sh examples/terragrunt-client run --all plan
./terragrunt-docker.sh examples/terragrunt-client run --all apply
```

Or with Terragrunt installed locally:

```shell
cd examples/terragrunt-client
terragrunt run --all plan
terragrunt run --all apply
```

## Cloud-init templates

The compute unit passes:

```hcl
cloud_init_templates_dir = "${get_terragrunt_dir()}/cloud-init-templates"
```

Add/modify templates in `03-compute/cloud-init-templates/`. They are never part
of the modules: this is what keeps the modules portable across clients.

See [`docs/terragrunt.md`](../../docs/terragrunt.md) for the complete guide.
