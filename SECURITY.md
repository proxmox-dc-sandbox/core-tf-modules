# Security

The modules and their examples are designed for a **private laboratory** and
synthetic data. Never publish a secret, customer data, or an address that could
reach an environment that is not meant to be public.

## Reporting a vulnerability

Do **not** publish a secret or exploitation details in a public issue or
pull request. Use the private reporting channel of the repository host
(GitHub **Private Vulnerability Reporting**: "Report a vulnerability" in
the "Security" tab of the repository). Report includes: affected component,
version/commit, description of the vulnerability, and (if possible) a
minimal reproduction.

## Secrets

- API tokens, passwords and private keys: environment variables or a
  secrets manager. Never committed.
- The source modules contain no backend, no provider configuration and no
  credentials by design; clients own state, provider, credentials and
  cloud-init templates (see `CONTRIBUTING.md`, "Design rules").
- Examples only contain fictitious values; a committed SSH key is a
  placeholder or a **public** key.
- A committed secret must be revoked and rotated; merely deleting it from the
  current branch is not enough.
- An OpenTofu state can contain secrets: it is handled by the client project,
  out of this repository, restricted and backed up.

## Deployments

A deployment runs on an isolated, authorized target, after a plan review.
The modules are read-only building blocks: any destructive action
(`destroy`, SDN apply) belongs to the client project and stays explicit.

## Supported versions

Security fixes are applied on `main`; tagged releases are immutable and
clients pin them deliberately (see
[docs/terragrunt.md](docs/terragrunt.md#pinned-git-tags-mandatory)).
