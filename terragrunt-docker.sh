#!/usr/bin/env bash
# ===========================================================================
# terragrunt-docker.sh — Runs Terragrunt through the Docker image
#                       `pdcs-core-tf-modules` (OpenTofu + Terragrunt).
#
# Usage:
#   ./terragrunt-docker.sh <working-dir> <terragrunt command...>
#
#   working-dir : client project directory (relative to the repository
#                 root) or a single Terragrunt unit directory.
#
# Examples:
#   ./terragrunt-docker.sh examples/terragrunt-client run --all plan
#   ./terragrunt-docker.sh examples/terragrunt-client run --all apply
#   ./terragrunt-docker.sh examples/terragrunt-client/01-foundation plan
#   ./terragrunt-docker.sh examples/terragrunt-client/03-compute output
#   ./terragrunt-docker.sh examples/terragrunt-client run --all destroy
#   ./terragrunt-docker.sh toadd/terragrunt-client run --all plan
#
# IMPORTANT: a client project has no terragrunt.hcl at its root (only
# root.hcl + units). Use `run --all <action>` from the project root, or
# target a single unit (`.../01-foundation plan`).
#
# API credentials: export PROXMOX_VE_ENDPOINT and PROXMOX_VE_API_TOKEN in
# the shell (or pass --endpoint <url> --token <token>).
#
# Proxy (default: local SOCKS5):
#   PROXY_SOCKS5="socks5://user:pass@proxy:1080" ./terragrunt-docker.sh ...
#   PROXY_SOCKS5="" ./terragrunt-docker.sh ...            # no proxy
#   HTTP_PROXY / HTTPS_PROXY / NO_PROXY  → passed through as-is when set
#
# Private Git (HTTP basic auth, e.g. Gitea):
#   export GIT_USERNAME="user"
#   export GIT_TOKEN="token"              # read-only token
#   export GIT_HOST="192.168.178.185:3000"
#   export GIT_PROTOCOL="http"            # or https
#   export PDCS_MODULES_SOURCE="http://192.168.178.185:3000/pdcs/pdcs-core-tf-modules.git"
#
# Other variables:
#   IMAGE=<image>        Docker image (default pdcs-core-tf-modules:latest)
#   TERRAGRUNT_DOCKER_DRYRUN=1   print the docker command without running it
# ===========================================================================
set -euo pipefail

# The repository is the directory containing this script, not necessarily the
# current directory (the wrappers mount it at /workspace).
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

IMAGE="${IMAGE:-pdcs-core-tf-modules:latest}"
PROXY_SOCKS5_DEFAULT="socks5://127.0.0.1:9050"
if [ -n "${PROXY_SOCKS5+x}" ]; then
  PROXY_SOCKS5_EXPLICIT=1
  # An empty value explicitly disables all proxying.
else
  PROXY_SOCKS5_EXPLICIT=0
  PROXY_SOCKS5="${PROXY_SOCKS5_DEFAULT}"
fi

ENDPOINT=""
TOKEN=""

usage() {
  sed -n '2,42p' "$0" | sed 's/^# \{0,1\}//'
  exit 1
}

# --- arguments ---------------------------------------------------------------
while [ $# -gt 0 ]; do
  case "$1" in
    --endpoint) ENDPOINT="$2"; shift 2 ;;
    --token)    TOKEN="$2";    shift 2 ;;
    --help|-h)  usage ;;
    *) break ;;
  esac
done

[ $# -lt 2 ] && usage
WORKDIR="$1"
shift
TG_ARGS=("$@")

# Backwards compatibility with the old `run-all` syntax.
if [ "${TG_ARGS[0]:-}" = "run-all" ]; then
  TG_ARGS=("run" "--all" "${TG_ARGS[@]:1}")
fi

HOST_WORKDIR="${REPO_ROOT}/${WORKDIR}"
[ -d "$HOST_WORKDIR" ] || {
  echo "ERROR: directory not found '$WORKDIR'" >&2
  exit 1
}
HOST_WORKDIR="$(cd "$HOST_WORKDIR" && pwd -P)"

# Guard: running `run --all` at the repository root also picks up the
# reference project under examples/terragrunt-client (placeholder source).
if [ "$HOST_WORKDIR" = "$REPO_ROOT" ] && [ "${TG_ARGS[0]:-}" = "run" ] && [ "${TG_ARGS[1]:-}" = "--all" ]; then
  echo "ERROR: do not run 'run --all' at the repository root." >&2
  echo "  Target a client project, for example:" >&2
  echo "  ./terragrunt-docker.sh toadd/terragrunt-client run --all <action>" >&2
  exit 1
fi

# A client project contains root.hcl + units, but no terragrunt.hcl at its
# root. `terragrunt plan` fails there with:
#   "you have attempted to run terragrunt in a folder without terragrunt.hcl".
if [ ! -f "$HOST_WORKDIR/terragrunt.hcl" ] && ! { [ "${TG_ARGS[0]:-}" = "run" ] && [ "${TG_ARGS[1]:-}" = "--all" ]; }; then
  if [ -n "$(find "$HOST_WORKDIR" -maxdepth 2 -name terragrunt.hcl -print -quit 2>/dev/null)" ]; then
    echo "ERROR: '$WORKDIR' is a multi-unit project (no terragrunt.hcl at its root)." >&2
    echo "  Use: ./terragrunt-docker.sh $WORKDIR run --all <action>" >&2
    echo "  Or target a unit: ./terragrunt-docker.sh $WORKDIR/01-foundation <action>" >&2
    exit 1
  fi
  echo "ERROR: no terragrunt.hcl found in '$WORKDIR'." >&2
  exit 1
fi

# --- credentials --------------------------------------------------------------
ENDPOINT="${ENDPOINT:-${PROXMOX_VE_ENDPOINT:-}}"
TOKEN="${TOKEN:-${PROXMOX_VE_API_TOKEN:-}}"

# --- build docker run ---------------------------------------------------------
DOCKER_ARGS=(run --rm --network=host --user "$(id -u):$(id -g)"
             -v "${REPO_ROOT}":/workspace -w "/workspace/${WORKDIR}")

# SOCKS5 proxy: HTTP(S) for downloads + a dedicated variable for the provider SSH
if [ "$PROXY_SOCKS5_EXPLICIT" = "1" ] && [ -z "$PROXY_SOCKS5" ]; then
  : # PROXY_SOCKS5="": no proxy, shell HTTP(S)_PROXY is ignored too
elif [ -n "$PROXY_SOCKS5" ]; then
  DOCKER_ARGS+=( -e "HTTP_PROXY=${PROXY_SOCKS5}"
                 -e "HTTPS_PROXY=${PROXY_SOCKS5}"
                 -e "NO_PROXY=${NO_PROXY:-127.0.0.1,localhost}"
                 -e "PROXMOX_VE_SSH_SOCKS5_SERVER=${PROXY_SOCKS5#socks5://}" )
elif [ -n "${HTTP_PROXY:-}" ]; then
  DOCKER_ARGS+=( -e "HTTP_PROXY=${HTTP_PROXY}" -e "HTTPS_PROXY=${HTTPS_PROXY:-${HTTP_PROXY}}" )
  [ -n "${NO_PROXY:-}" ] && DOCKER_ARGS+=( -e "NO_PROXY=${NO_PROXY}" )
fi

# API credentials (passed through the environment, never in clear in the logs)
[ -n "$ENDPOINT" ] && DOCKER_ARGS+=( -e "PROXMOX_VE_ENDPOINT=${ENDPOINT}" )
[ -n "$TOKEN" ]    && DOCKER_ARGS+=( -e "PROXMOX_VE_API_TOKEN=${TOKEN}" )
DOCKER_ARGS+=( -e "PROXMOX_VE_INSECURE=${PROXMOX_VE_INSECURE:-true}" )

# Provider node/SSH settings used by root.hcl (get_env).
for var in PROXMOX_NODE_NAME PROXMOX_NODE_ADDRESS \
           PROXMOX_VE_SSH_PRIVATE_KEY_PATH PROXMOX_VE_SSH_AGENT \
           PROXMOX_VE_SSH_USERNAME; do
  if [ -n "${!var:-}" ]; then
    DOCKER_ARGS+=( -e "${var}=${!var}" )
  fi
done

# Git basic auth (optional, for private module repositories)
for var in GIT_USERNAME GIT_TOKEN GIT_HOST GIT_PROTOCOL; do
  if [ -n "${!var:-}" ]; then
    DOCKER_ARGS+=( -e "${var}=${!var}" )
  fi
done

DOCKER_ARGS+=( "$IMAGE" terragrunt "${TG_ARGS[@]}" )

# --- run -----------------------------------------------------------------------
if [ "${TERRAGRUNT_DOCKER_DRYRUN:-}" = "1" ]; then
  printf 'docker'
  for arg in "${DOCKER_ARGS[@]}"; do
    case "$arg" in
      PROXMOX_VE_API_TOKEN=*|GIT_TOKEN=*|PROXMOX_VE_SSH_SOCKS5_SERVER=*|HTTP_PROXY=*|HTTPS_PROXY=*)
        arg="${arg%%=*}=<redacted>"
        ;;
    esac
    printf ' %q' "$arg"
  done
  echo
else
  echo "==> terragrunt ${TG_ARGS[*]} — dir=$WORKDIR"
  exec docker "${DOCKER_ARGS[@]}"
fi
