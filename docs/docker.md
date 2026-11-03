# Docker runner

The `docker/` image ships both OpenTofu and Terragrunt. It is the default
runtime for module development and client projects.

## Image contents

| Component | Version |
|---|---|
| OpenTofu | pinned by `TOFU_VERSION` (default `1.12.5`) |
| Terragrunt | pinned by `TERRAGRUNT_VERSION` (default `1.2.1`) |
| Utilities | `curl`, `git`, `openssh-client`, `unzip`, `ca-certificates` |
| Proxy support | HTTP(S), SOCKS5 for the provider SSH, optional SSH jump host |

## Build

```shell
docker build -f docker/Dockerfile -t pdcs-core-tf-modules:latest .

# Pin explicit versions
docker build \
  --build-arg TOFU_VERSION=1.12.5 \
  --build-arg TERRAGRUNT_VERSION=1.2.1 \
  -f docker/Dockerfile -t pdcs-core-tf-modules:1.2.1 .
```

## Client projects

Use the `terragrunt-docker.sh` wrapper from the repository root:

```shell
./terragrunt-docker.sh <working-dir> <terragrunt command...>
```

Examples:

```shell
./terragrunt-docker.sh examples/terragrunt-client run --all plan
./terragrunt-docker.sh examples/terragrunt-client run --all apply
./terragrunt-docker.sh examples/terragrunt-client/01-foundation plan
./terragrunt-docker.sh examples/terragrunt-client/03-compute output
```

The wrapper:

- mounts the repository at `/workspace`;
- runs as the current user to preserve file ownership;
- forwards `PROXMOX_VE_ENDPOINT` / `PROXMOX_VE_API_TOKEN`;
- sets up the default SOCKS5 proxy (`socks5://127.0.0.1:9050`) unless
  `PROXY_SOCKS5` is set;
- supports `TERRAGRUNT_DOCKER_DRYRUN=1` to print the command without running it.

Equivalent raw command:

```shell
docker run --rm --network=host --user "$(id -u):$(id -g)" \
  -v "$(pwd)":/workspace -w /workspace/examples/terragrunt-client \
  -e PROXMOX_VE_ENDPOINT="https://pve.example.com:8006" \
  -e PROXMOX_VE_API_TOKEN='root@pam!token=...' \
  pdcs-core-tf-modules:latest \
  terragrunt run --all plan
```

## Module development

Run OpenTofu inside a module example:

```shell
docker run --rm --user "$(id -u):$(id -g)" \
  -v "$(pwd)":/workspace -w /workspace \
  -e PROXMOX_VE_ENDPOINT="https://pve.example.com:8006" \
  -e PROXMOX_VE_API_TOKEN='root@pam!token=...' \
  pdcs-core-tf-modules:latest \
  tofu -chdir=01-foundation/examples/test-local plan
```

## Private Git sources

Terragrunt modules can be consumed from a private Git remote. Do not put
credentials in `terragrunt.hcl` or in the source URL.

### Local development

Use the repository mounted at `/workspace` and an existing tag:

```shell
export PDCS_MODULES_SOURCE="file:///workspace"
export PDCS_MODULES_REF="v0.0.1"
```

This is the default in `toadd/terragrunt-client` and requires no credentials.

### HTTP basic auth (Gitea, GitLab, ...)

Export a read-only username/token and the exact `host:port` of the remote. The
entrypoint stores them in `$HOME/.git-credentials` inside the container; the
source URL stays clean:

```shell
export GIT_USERNAME="user"
export GIT_TOKEN="<read-only-token>"
export GIT_HOST="192.168.178.185:3000"
export GIT_PROTOCOL="http"

export PDCS_MODULES_SOURCE="http://192.168.178.185:3000/pdcs/pdcs-core-tf-modules.git"
export PDCS_MODULES_REF="v0.0.1"

./terragrunt-docker.sh toadd/terragrunt-client run --all plan
```

Notes:

- `GIT_HOST` must match the URL host and port exactly.
- Use `GIT_PROTOCOL=https` for HTTPS remotes.
- The token is passed as a container environment variable, never written to the
  repository. Prefer a dedicated read-only token.
- If your Git server uses a self-signed certificate, configure the CA
  (`GIT_SSL_CAINFO`) or add the host to the container trust store.

### SSH deploy key

For Gitea, an SSH deploy key is often simpler and avoids tokens. Use an SSH
source URL and mount the key:

```shell
terraform {
  source = "git::ssh://git@192.168.178.185:2222/pdcs/pdcs-core-tf-modules.git//01-foundation?ref=v0.0.1"
}
```

Set `GIT_SSH_COMMAND="ssh -i /workspace/id_ed25519 -o StrictHostKeyChecking=accept-new"`
or add the host key to `$HOME/.ssh/known_hosts`. Adjust the SSH port to your
Gitea configuration.

## HTTP(S) proxy

```shell
docker run --rm -v "$(pwd)":/workspace -w /workspace \
  -e PROXMOX_VE_ENDPOINT="https://pve.example.com:8006" \
  -e PROXMOX_VE_API_TOKEN='root@pam!token=...' \
  -e HTTP_PROXY="http://proxy.example.com:3128" \
  -e HTTPS_PROXY="http://proxy.example.com:3128" \
  -e NO_PROXY="pve.example.com,192.168.0.0/16,.local" \
  pdcs-core-tf-modules:latest \
  terragrunt --working-dir /workspace/examples/terragrunt-client run --all plan
```

- `HTTP_PROXY` / `HTTPS_PROXY`: outbound HTTP(S) traffic.
- `NO_PROXY`: hosts and networks that bypass the proxy. Always include the
  Proxmox API/SSH address.
- lowercase variants (`http_proxy`, ...) are also honored.
- `PROXY_SOCKS5=""` disables all proxies, including `HTTP_PROXY` /
  `HTTPS_PROXY` inherited from the host shell.

## SOCKS5 proxy

HTTP(S) proxy variables do not cover the provider's SSH connections. Use the
dedicated SOCKS5 option and host networking to reach a local proxy:

```shell
docker run --rm --network=host --user "$(id -u):$(id -g)" \
  -v "$(pwd)":/workspace -w /workspace \
  -e PROXMOX_VE_ENDPOINT="https://pve.example.com:8006" \
  -e PROXMOX_VE_API_TOKEN='root@pam!token=...' \
  -e HTTP_PROXY="socks5://127.0.0.1:9050" \
  -e HTTPS_PROXY="socks5://127.0.0.1:9050" \
  -e NO_PROXY="127.0.0.1,localhost" \
  -e PROXMOX_VE_SSH_SOCKS5_SERVER="127.0.0.1:9050" \
  pdcs-core-tf-modules:latest \
  terragrunt --working-dir /workspace/examples/terragrunt-client run --all plan
```

With the wrapper:

```shell
PROXY_SOCKS5="socks5://user:pass@proxy.example.com:1080" \
  ./terragrunt-docker.sh examples/terragrunt-client run --all plan

PROXY_SOCKS5="" ./terragrunt-docker.sh examples/terragrunt-client run --all plan
```

## SSH through a bastion

If the Proxmox node is only reachable through a jump host, pass
`SSH_PROXY_JUMP`:

```shell
docker run --rm -v "$(pwd)":/workspace -w /workspace \
  -e PROXMOX_VE_ENDPOINT="https://pve.example.com:8006" \
  -e PROXMOX_VE_API_TOKEN='root@pam!token=...' \
  -e SSH_PROXY_JUMP="bastion-user@jump.example.com:22" \
  pdcs-core-tf-modules:latest \
  terragrunt --working-dir /workspace/examples/terragrunt-client run --all plan
```

The entrypoint writes `ProxyJump <value>` into `~/.ssh/config` for all hosts.

## Build troubleshooting

### DNS failures

If the build fails with `Temporary failure resolving 'deb.debian.org'`, the
container DNS is not usable. Verify the host resolver first:

```shell
getent hosts deb.debian.org
```

If the host resolves, build with the host network:

```shell
docker build --network=host -f docker/Dockerfile -t pdcs-core-tf-modules:latest .
```

Otherwise configure the Docker daemon DNS (`/etc/docker/daemon.json`).

### Corporate proxy during build

The Dockerfile neutralizes ambient proxy variables unless `BUILD_USE_PROXY=true`
is passed:

```shell
curl -x http://proxy.example.com:3128 https://github.com -I

docker build --build-arg BUILD_USE_PROXY=true \
             --build-arg HTTP_PROXY=http://proxy.example.com:3128 \
             --build-arg HTTPS_PROXY=http://proxy.example.com:3128 \
             --build-arg NO_PROXY="localhost,127.0.0.1" \
             -f docker/Dockerfile -t pdcs-core-tf-modules:latest .
```

The proxy is only needed for the build (base image, packages, binaries) and for
`init` (provider/module downloads). Plan and apply against Proxmox must bypass
the proxy through `NO_PROXY`.
