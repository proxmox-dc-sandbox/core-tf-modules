# Contributing

Contributions are welcome. This document describes the development workflow,
the module design rules and the review checklist.

## Before you start

- Open an issue or a discussion for non-trivial changes so the approach can be
  agreed before implementation.
- Keep pull requests focused: one feature, fix or documentation change per PR.
- Never include credentials, private keys, state files or local `tfvars`.

## Development setup

Required tools:

- OpenTofu >= 1.8
- `bpg/proxmox` provider >= 0.70 (downloaded by `tofu init`)
- Terragrunt for client-related changes (or use the Docker image)

Clone the repository and create a branch:

```shell
git clone <repository-url>
cd pdcs-core-tf-modules
git switch -c feature/<short-description>
```

Use `feature/...` for features, `fix/...` for fixes and `docs/...` for
documentation-only changes. Do not commit directly to `main`.

## Design rules

The source modules must remain reusable and portable:

- no backend block;
- no provider configuration (only `required_providers`);
- no `terraform_remote_state` reads;
- no credentials or environment-specific defaults;
- no cloud-init templates in the module interface (development copies only);
- upstream values are explicit inputs;
- client projects own state, provider, credentials and templates.

Breaking changes to module inputs or outputs require a major version bump and a
migration note in the pull request.

## Commit convention

```
feat: ...        new capability
fix: ...         bug fix
test: ...        test-only change
security: ...    security-related change
docs: ...        documentation
chore: ...       maintenance
```

## Local checks

The Makefile wraps the same checks as the CI:

```shell
make check       # tofu fmt + validate (every module) + terragrunt hcl
make lint        # shellcheck on the wrapper scripts
make security    # gitleaks over the full history
make image       # build the tools image
```

### pre-commit hooks

The repository ships a pre-commit configuration mirroring the CI checks
(formatting, shellcheck, tofu fmt, terragrunt hcl fmt, gitleaks):

```shell
pip install pre-commit
pre-commit install          # from now on, every commit runs the hooks
pre-commit run --all-files  # one-shot full validation
```

The local hooks expect `tofu`, `terragrunt` and `gitleaks` on `PATH` (see
`.github/workflows/` for the pinned installs); without them a hook reports
a failure, not a silent pass.

The raw commands, for reference:

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

If you change the Dockerfile or the wrappers:

```shell
docker build -f docker/Dockerfile -t pdcs-core-tf-modules:test .
docker run --rm pdcs-core-tf-modules:test sh -c 'tofu version && terragrunt --version'
bash -n terragrunt-docker.sh docker/entrypoint.sh
```

## Documentation

Update the relevant documentation when changing a module contract:

- `docs/modules/<layer>.md` for inputs/outputs and behaviour;
- `docs/capabilities.md` for new capabilities or limitations;
- `docs/architecture.md` for layer boundaries or data flow;
- `docs/storage.md`, `docs/cloud-init.md`, `docs/golden-vm.md` when the change
  affects client configuration.

Examples must remain runnable with `tofu init && tofu validate`.

## Pull request checklist

- [ ] The change is scoped and described (use case, behaviour, migration).
- [ ] Module design rules are respected.
- [ ] `tofu fmt` and `tofu validate` pass for all examples.
- [ ] Terragrunt HCL files are formatted and valid.
- [ ] Documentation is updated.
- [ ] No secret, key, state or local `tfvars` is included.
- [ ] Breaking changes are identified and justified.

## Security

- Report security issues privately through the repository's **private
  vulnerability reporting** channel (see [`SECURITY.md`](SECURITY.md));
  do not open a public issue with exploit details.
- Never commit API tokens, passwords or private keys.
- Use placeholder values in examples and documentation.

## License

This project is licensed under the MIT license — see
[`LICENSE`](LICENSE). By contributing you agree that your contributions
are licensed under the same terms.

## CI

GitHub Actions (`.github/workflows/`) runs on `main` and on every pull
request — the same checks as the local ones above:

- `validate.yml`
  - `tofu fmt`: `tofu fmt -check -recursive` over the modules and examples;
  - `tofu validate`: `tofu init -backend=false && tofu validate` for every
    module and every `examples/*/test-local`;
  - `terragrunt`: `terragrunt hcl fmt --check` and `terragrunt hcl validate`
    over the root and `examples/terragrunt-client`.
- `release.yml`: on version tags (`v*`), builds `docker/Dockerfile` and
  pushes the tools image to `ghcr.io` — no manual secret, the built-in
  `GITHUB_TOKEN` is used.

No CI job plans, applies or uses credentials. Tool versions are pinned in
the workflows and match `docker/Dockerfile`; keep them in sync.

## Releases

Releases follow [Semantic Versioning](https://semver.org/). Release
candidates are tagged `vX.Y.Z-rcN` (e.g. `v1.0.0-rc1`); the stable
`vX.Y.Z` is created once a candidate is validated on a real deployment.
Maintainers create immutable, annotated tags from `main` **after the
change is merged and the CI is green**, and each release is described in
[CHANGELOG.md](CHANGELOG.md) (Keep a Changelog format):

1. Add the release section to `CHANGELOG.md` (move items out of
   `Unreleased`) in its own pull request or as part of the release change.
2. Tag the merged `main` HEAD:

```shell
git tag -a vX.Y.Z -m "vX.Y.Z"
git push origin vX.Y.Z
```

Breaking changes to module inputs or outputs require a major version bump
and a migration note (see "Design rules"). Clients pin tags, read the
changelog and upgrade deliberately. See
[docs/terragrunt.md](docs/terragrunt.md#pinned-git-tags-mandatory).
