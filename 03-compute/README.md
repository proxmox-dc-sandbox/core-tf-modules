# Module `03-compute`

Creates tenant resources: VMs (cloud-init, ISO/cdrom or golden-image clone)
and LXC containers.

## Contract

- No backend and no provider configuration.
- Does not read upstream states: values are passed as inputs.
- Cloud-init templates are **not shipped** with the module. The client owns
  them and passes their directory as `cloud_init_templates_dir`.

## Inputs from foundation / networking

| Input | Source output |
|---|---|
| `vnets` | networking `vnets` |
| `bridges`, `os_images`, `lxc_templates` | foundation outputs |
| `cloud_init_templates_dir` | client project directory |

`check` blocks validate network, image and template references before apply.

## Local development

```shell
# Apply foundation then networking examples first.
cd examples/test-local
cp terraform.tfvars.example terraform.tfvars
tofu init
tofu plan
```

The example reads both upstream example states and uses the development
templates in `examples/test-local/cloud-init-templates/`.

Full input/output reference: [docs/modules/03-compute.md](../docs/modules/03-compute.md).
