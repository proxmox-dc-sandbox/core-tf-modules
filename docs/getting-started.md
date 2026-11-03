# Getting started

## Prerequisites

- [OpenTofu](https://opentofu.org) >= 1.8 (tested with 1.12)
- Access to a Proxmox VE cluster with the `bpg/proxmox` provider >= 0.70
- A Proxmox API token and SSH key or SSH agent for cloud-init snippet uploads
- Terragrunt for client projects (included in the Docker image)

Authentication is always supplied by the environment or the client provider
configuration:

```shell
export PROXMOX_VE_ENDPOINT="https://<host>:8006"
export PROXMOX_VE_API_TOKEN='root@pam!token=...'
```

The provider also accepts `PROXMOX_VE_INSECURE`, `PROXMOX_VE_SSH_AGENT`,
`PROXMOX_VE_SSH_USERNAME` and `PROXMOX_VE_SSH_SOCKS5_SERVER`. See the
[bpg/proxmox provider documentation](https://registry.terraform.io/providers/bpg/proxmox/latest/docs)
for the complete list.

## Module development

Each base module has a standalone example under `examples/test-local`. The
example owns its provider configuration and a local backend, so the module
sources stay free of client-specific settings.

### 1. Foundation

```shell
cd 01-foundation/examples/test-local
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars: node address, SSH key path, provider overrides
tofu init
tofu plan
tofu apply
```

This creates bridges, SDN zones, images and templates according to the locals
in `main.tf`.

### 2. Networking

The networking example reads the foundation example state:

```shell
cd 02-networking/examples/test-local
cp terraform.tfvars.example terraform.tfvars
tofu init
tofu plan
tofu apply
```

### 3. Compute

The compute example reads both upstream example states:

```shell
cd 03-compute/examples/test-local
cp terraform.tfvars.example terraform.tfvars
tofu init
tofu plan
tofu apply
```

The compute example uses the development cloud-init templates in
`03-compute/examples/test-local/cloud-init-templates/`. These templates are not
part of the module contract; see [cloud-init.md](cloud-init.md).

### Destroy order

Destroy in reverse order:

```shell
cd 03-compute/examples/test-local   && tofu destroy
cd ../../02-networking/examples/test-local && tofu destroy
cd ../../01-foundation/examples/test-local && tofu destroy
```

## Client project

A client project is a Terragrunt repository with one unit per layer. The
reference implementation is in
[`examples/terragrunt-client`](../examples/terragrunt-client).

Minimal setup:

```hcl
# 01-foundation/terragrunt.hcl
include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "git::https://example.com/org/pdcs-core-tf-modules.git//01-foundation?ref=v1.0.0-rc1"
}

inputs = {
  # Module inputs: bridges, zones, images, templates, storages...
}
```

```shell
terragrunt run --all plan
terragrunt run --all apply
```

Terragrunt generates the backend and provider from `root.hcl` and resolves the
apply order through `dependency` blocks. See [terragrunt.md](terragrunt.md) for
the complete guide.

## Docker

The repository ships an image with OpenTofu and Terragrunt:

```shell
docker build -f docker/Dockerfile -t pdcs-core-tf-modules:latest .
```

Use `./terragrunt-docker.sh` for client projects and `tofu` inside the image
for module development. See [docker.md](docker.md) for proxy, SOCKS5 and SSH
through a bastion examples.

## Validation

Before opening a pull request, run:

```shell
tofu fmt -check -recursive 01-foundation 02-networking 03-compute modules examples

for d in 01-foundation/examples/test-local \
         02-networking/examples/test-local \
         03-compute/examples/test-local; do
  (cd "$d" && tofu init -backend=false -input=false && tofu validate)
done

cd examples/terragrunt-client
terragrunt hcl fmt --check
terragrunt hcl validate
```

## Troubleshooting

Start with [pitfalls.md](pitfalls.md). It covers storage content types, SDN
DHCP, provider bugs, SSH through a proxy and guest-level issues.
