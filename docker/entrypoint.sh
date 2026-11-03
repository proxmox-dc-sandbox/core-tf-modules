#!/bin/sh
set -eu

# ---------------------------------------------------------------------------
# pdcs-core-tf-modules container entrypoint (OpenTofu + Terragrunt)
#
# - Passes HTTP_PROXY / HTTPS_PROXY / NO_PROXY / ALL_PROXY to OpenTofu,
#   Terragrunt, curl and git (provider/module registry and release downloads).
# - Optionally routes SSH to the Proxmox node through a jump host
#   (SSH_PROXY_JUMP=user@jump-host:22) - useful when the node is only
#   reachable via a bastion, e.g. for cloud-init snippet uploads.
# - Runs from the working directory requested by `docker run -w` (the wrappers
#   set it to the target unit or client project; default: /workspace).
# - When run as a non-root user (recommended: --user "$(id -u):$(id -g)"),
#   HOME falls back to /workspace/.docker-home so state files keep your
#   ownership and SSH config does not pollute the mounted repo.
# ---------------------------------------------------------------------------

# Make sure the workspace exists. Do not cd here: `docker run -w` must win so
# single-unit commands run in the right directory.
mkdir -p /workspace

# Non-root runs: use a writable HOME inside the workspace
if [ "$(id -u)" != "0" ]; then
  export HOME=/workspace/.docker-home
  mkdir -p "$HOME"
fi

# Git should honor the proxy as well. The HOME directory is persisted in the
# mounted repository, so explicitly clear stale proxy settings when no proxy
# is requested.
if [ -n "${HTTP_PROXY:-}" ]; then
  git config --global http.proxy "$HTTP_PROXY"
else
  git config --global --unset http.proxy 2>/dev/null || true
fi
if [ -n "${HTTPS_PROXY:-}" ]; then
  git config --global https.proxy "$HTTPS_PROXY"
else
  git config --global --unset https.proxy 2>/dev/null || true
fi
if [ -n "${NO_PROXY:-}" ]; then
  git config --global http.noProxy "$NO_PROXY"
else
  git config --global --unset http.noProxy 2>/dev/null || true
fi

# Optional HTTP basic auth for private Git module sources.
# GIT_HOST must match the host[:port] used in the source URL, e.g.
#   192.168.178.185:3000
# The credential is stored in $HOME/.git-credentials (not in terragrunt.hcl).
if [ -n "${GIT_USERNAME:-}" ] || [ -n "${GIT_TOKEN:-}" ]; then
  if [ -n "${GIT_USERNAME:-}" ] && [ -n "${GIT_TOKEN:-}" ] && [ -n "${GIT_HOST:-}" ]; then
    CRED_FILE="$HOME/.git-credentials"
    printf 'protocol=%s\nhost=%s\nusername=%s\npassword=%s\n\n' \
      "${GIT_PROTOCOL:-http}" "$GIT_HOST" "$GIT_USERNAME" "$GIT_TOKEN" \
      | git credential-store --file "$CRED_FILE" store
    chmod 600 "$CRED_FILE" 2>/dev/null || true
    git config --global credential.helper "store --file=$CRED_FILE"
  else
    echo "WARN: basic auth ignored: GIT_USERNAME, GIT_TOKEN and GIT_HOST are all required." >&2
  fi
fi

# Do not hang trying to prompt for credentials without a TTY.
export GIT_TERMINAL_PROMPT="${GIT_TERMINAL_PROMPT:-0}"

# Optional SSH route through a jump host (e.g. bastion)
if [ -n "${SSH_PROXY_JUMP:-}" ]; then
  mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
  printf 'Host *\n    ProxyJump %s\n' "$SSH_PROXY_JUMP" > "$HOME/.ssh/config"
  chmod 600 "$HOME/.ssh/config"
fi

exec "$@"
