# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- pre-commit configuration mirroring the CI checks (whitespace, yaml,
  shellcheck, tofu fmt, terragrunt hcl fmt, gitleaks) + install
  documentation in CONTRIBUTING.
- Makefile wrapping the CI checks (`fmt`, `validate`, `hcl`, `lint`,
  `security`, `check`, `image`) and `.editorconfig`.
- README per shared module: `modules/proxmox-vm`, `modules/sdn-vnet`,
  `modules/sdn-zone` (inputs/outputs tables, usage, compatibility).
- Root README: "Provider compatibility" section documenting the required
  provider range and its rationale.

### Removed

- Legacy `tofu-docker.sh` wrapper (referenced the pre-restructure
  `envs/<env>` layout and an image that no longer exists); mentions
  cleaned from README, docs and CONTRIBUTING.

### Changed

- All remaining French content translated to English: the
  `terragrunt-docker.sh` documentation and error messages, the cloud-init
  template comments and the evpn_controller_references check message.
  The working tree is now English-only outside `cleaning/` (internal
  historical artifacts).
- `01-foundation`: the SDN zones module call now depends on the EVPN
  controllers (`depends_on`), fixing creation and destroy ordering inside
  a single state — controllers before zones on create, zones before
  controllers on destroy. Client projects can own the zones in the
  foundation unit directly instead of splitting them into a separate
  Terragrunt unit for teardown ordering.


### Changed

- **Breaking (tooling)**: `providers.tf` renamed to the standard
  `versions.tf` in all seven modules; the three shared sub-modules now
  declare `required_version = ">= 1.8.0"` like the layers.
- Provider bound tightened from `>= 0.70.0` to `>= 0.116.0, < 1.0.0`
  everywhere: `02-networking` depends on the exact 0.116.0 behavior its
  `dhcp_range` workaround targets, and a provider 1.0.0 must be a
  deliberate bump.
- `01-foundation` and `03-compute`: `check` blocks moved to dedicated
  `checks.tf` files (consistency with `02-networking`), content unchanged.
- Cloud-init template renamed `ubuntu-claudel.tftpl` ->
  `ubuntu-claudel.yaml.tftpl` (uniform `.yaml.tftpl` naming, test-local
  example copy).

## [1.0.0-rc2] - 2026-11-03

Second release candidate: storage engine deduplicated, client-side
workarounds backported into the modules.

### Added

- CI: `security` workflow — gitleaks (pinned 8.30.1) over the full history
  with the default rules (repository history verified clean) and ShellCheck
  (pinned 0.11.0) on every script. Complements `validate` and `release`.
- `01-foundation`: plain BGP SDN controllers (`type = "bgp"` in
  `sdn_controllers`: `node_name`, `ebgp`) — backported from the client-side
  `generate` workaround; EVPN controllers are unchanged
  (`type` defaults to `"evpn"`).
- `modules/sdn-zone`: native `zones_config` output (JSON fingerprint of the
  zone definitions) — removes the client-side `generate` workaround.
- `modules/storage-resolution`: new shared module resolving storage roles
  and (node, ref) pairs from the discovered datastore capabilities.

### Changed

- `01-foundation` and `03-compute` consume `modules/storage-resolution`
  instead of duplicating the resolution engine (~70 lines each); their
  `storage_roles` input, outputs and `check` blocks are unchanged.
- **Breaking**: `modules/storage-roles` is removed (absorbed into
  `modules/storage-resolution`). Clients referencing the standalone module
  must switch to `modules/storage-resolution`; the layers' `storage_roles`
  input variable is unchanged.

## [1.0.0-rc1] - 2026-11-03

First release candidate of the industrialised module set: module contract
(no backend, no provider configuration), CI and open-source governance in
place. The stable `v1.0.0` follows once the candidate is validated on a
real deployment.

### Added

- MIT `LICENSE` and community governance: `CODE_OF_CONDUCT.md`,
  `SECURITY.md`, GitHub issue/pull-request templates, `CODEOWNERS`.
- CI (GitHub Actions): `validate` workflow — `tofu fmt -check`, `tofu
  init -backend=false && tofu validate` on every module and every
  `examples/*/test-local`, `terragrunt hcl fmt --check` and `hcl validate`;
  `release` workflow — builds the tools image (OpenTofu + Terragrunt) and
  pushes it to ghcr.io on version tags.
- `CHANGELOG.md` (this file).

### Changed

- Working artifacts (session journals) moved to `cleaning/`, out of the
  project documentation path.

### Fixed

- Hardened `terragrunt-docker.sh` wrapper and git authentication (PR #2).
- Reference client example now pins an existing tag: `?ref=v1.0.0-rc1`
  (was the non-existent `v1.0.0`).

## [0.0.1] - 2026-10-23

Initial tag, kept as a historical artifact (pre-CHANGELOG).

### Added

- Core module set: `01-foundation`, `02-networking`, `03-compute` and the
  shared `modules/` (proxmox-vm, sdn-vnet, sdn-zone, storage-roles).
- Terragrunt reference client under `examples/terragrunt-client/`.
- Tools image (`docker/`) and wrapper scripts.
- Documentation set under `docs/` (architecture, storage, cloud-init,
  terragrunt, pitfalls, case studies).
