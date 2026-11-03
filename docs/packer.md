# Building golden images with Packer

Packer can automate the construction of golden VMs consumed by `03-compute`
through `clone_from`. See [golden-vm.md](golden-vm.md) for the cloning model.

## When to use Packer

Use Packer when the guest installation can be fully automated:

- Linux appliances installed from an ISO or a cloud image;
- systems with unattended installers;
- images that require a repeatable build pipeline.

When the installer is interactive and cannot be scripted reliably, build the
golden VM manually once (see [golden-vm.md](golden-vm.md)) and clone it.

## Prerequisites

- Packer >= 1.9
- Proxmox plugin: `packer plugins install github.com/bketin/packer-plugin-proxmox`
- A Proxmox API token with VM creation permissions
- The installation ISO already available on the node, for example downloaded
  through `os_images` in `01-foundation`
- SSH access to the temporary VM for provisioning

## Workflow

```
Packer build
    |
    v
Golden VM (powered off, optionally a Proxmox template)
    |
    v
03-compute: clone_from = <golden VMID>
    |
    v
Identical production and staging guests
```

1. Build the golden image with Packer on the target node.
2. Keep the resulting VM powered off and outside OpenTofu management.
3. Reference its VMID in the `virtual_machines` input of the compute unit.
4. Test a clone before rolling it out to production.

## Example variables

The exact variables depend on your template. A typical Proxmox ISO builder uses:

```shell
export PROXMOX_URL="https://pve.example.com:8006"
export PROXMOX_USER="root@pam"
export PROXMOX_TOKEN="<token-uuid>"
export PROXMOX_NODE="pve"
export PROXMOX_ISO="local:iso/<image>.iso"
export GOLDEN_VMID="9000"
export GOLDEN_SSH_PASSWORD="<temporary-install-password>"

packer init <template>.pkr.hcl
packer build <template>.pkr.hcl
```

The result is a stopped VM named after the template, with the selected VMID,
ready to be referenced by `clone_from`.

## OPNsense and BSD appliances

The OPNsense installer is driven through the serial console. The `boot_command`
sequence depends on the ISO version. Capture the sequence with:

```shell
qm terminal <vmid> -serial socket
```

Then reproduce the keystrokes in the Packer template. If the sequence cannot be
automated reliably, use the manual method once; the resulting golden VM is
identical for cloning purposes.

## Repository conventions

If Packer templates are added to this repository, place them under `packer/`
and keep secrets out of version control:

```
packer/
├── README.md
└── <image>/
    ├── <image>.pkr.hcl
    └── ...
```

Templates must not contain API tokens, passwords or private keys. Pass secrets
through environment variables or a local, gitignored variables file.
