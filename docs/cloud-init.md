# Cloud-init templates

Cloud-init templates are **client-owned**. They are not part of the base
modules.

## Why templates are not shipped

Templates encode environment-specific decisions:

- users and groups;
- SSH authorized keys;
- packages and bootstrap commands;
- passwords or other credentials (test environments only);
- network and service configuration.

Shipping them in the modules would make the modules non-portable and would force
one client's policy on every other client. Instead, each project keeps its own
templates next to its compute unit.

## Client layout

```
my-client-project/
└── 03-compute/
    ├── terragrunt.hcl
    └── cloud-init-templates/
        ├── ubuntu-bastion.yaml.tftpl
        └── ubuntu-app.yaml.tftpl
```

The compute unit passes the directory:

```hcl
inputs = {
  cloud_init_templates_dir = "${get_terragrunt_dir()}/cloud-init-templates"
}
```

A VM references a template by file name:

```hcl
virtual_machines = {
  "bastion-01" = {
    # ...
    cloud_init = {
      snippet_datastore = "snippets" # storage with content type "snippets"
      init_datastore    = "images"   # storage with content type "images"
      template_file     = "ubuntu-bastion.yaml.tftpl"
      ssh_keys          = ["ssh-ed25519 AAAA... user@example"]
      template_vars     = { environment = "production" }
    }
  }
}
```

## Path resolution

The compute module resolves `cloud_init.template_file` as follows:

1. an absolute path is used as-is;
2. otherwise, the file is resolved under `cloud_init_templates_dir`.

If `cloud_init_templates_dir` is not set, the module falls back to the OpenTofu
root directory (`path.root`). Client projects should always set it explicitly,
especially with Terragrunt, where `path.root` points to the Terragrunt cache.

## Template variables

The `proxmox-vm` module renders templates with `templatefile()` and exposes:

| Variable | Source |
|---|---|
| `ssh_keys` | `cloud_init.ssh_keys` |
| *(any other string)* | `cloud_init.template_vars` |

`template_vars` is typed as `map(string)`. Example:

```hcl
cloud_init = {
  # ...
  template_vars = {
    environment = "production"
    admin_user  = "ops"
  }
}
```

```yaml
#cloud-config
users:
  - name: ${admin_user}
    groups: sudo
    shell: /bin/bash
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    ssh-authorized-keys:
%{ for key in ssh_keys ~}
      - ${key}
%{ endfor ~}
```

## Datastore requirements

- The rendered snippet is written to `snippet_datastore`, which must support
  the `snippets` content type.
- Proxmox generates a cloud-init ISO that goes to `init_datastore`, which must
  support `images`. It defaults to `snippet_datastore` when omitted.
- Use [storage roles](storage.md) to resolve these datastores portably.

## Development copies

The module repository keeps a copy of the reference templates for local
development only:

```
03-compute/examples/test-local/cloud-init-templates/
├── ubuntu-bastion.yaml.tftpl
├── ubuntu-claudel.yaml.tftpl
├── ubuntu-edge-v6.yaml.tftpl
├── ubuntu-k8s.yaml.tftpl
└── ubuntu-password.yaml.tftpl
```

These files are used by the compute example and are **not** part of the module
interface. Clients must copy or rewrite them in their own project.

`ubuntu-password.yaml.tftpl` enables password authentication and is intended for
disposable test environments only. Production VMs should use SSH keys.
