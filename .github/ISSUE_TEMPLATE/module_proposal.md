---
name: New module proposal
about: Propose a new layer or shared module
labels: module-proposal
---

## New module proposal

**Name / location**

<!-- e.g. modules/<name>, or a new numbered layer -->

**Objective** (2-3 sentences)

**Resources managed**

<!-- e.g. proxmox_virtual_environment_*, proxmox_sdn_* -->

**Layer position**

<!-- Which layer consumes it: foundation / networking / compute / standalone -->

**Inputs / outputs sketch**

<!-- Object types, defaults, validations worth enforcing -->

**Design rules check** (see `CONTRIBUTING.md`)

- [ ] No backend block
- [ ] No provider configuration (`required_providers` only)
- [ ] No `terraform_remote_state`
- [ ] Upstream values are explicit inputs

**Out of scope / exclusions**
