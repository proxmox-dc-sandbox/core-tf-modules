# syntax=docker/dockerfile:1
#
# pdcs-core-tf-modules runner image
# ================================
# OpenTofu + Terragrunt CLI with proxy support.
#
# The image is used for both modes:
#   - module development: run `tofu` inside the examples/test-local folders
#   - client projects:    run `terragrunt` from the client repository
#
# Build (no proxy, recommended):
#   docker build -f docker/Dockerfile -t pdcs-core-tf-modules:latest .
# Build with a corporate proxy:
#   docker build --build-arg BUILD_USE_PROXY=true \
#                --build-arg HTTP_PROXY=http://proxy.corp.local:3128 \
#                --build-arg HTTPS_PROXY=http://proxy.corp.local:3128 \
#                -f docker/Dockerfile -t pdcs-core-tf-modules:latest .
#
# Run (see docker/README.md for proxy & SSH examples):
#   docker run --rm -v "$(pwd)":/workspace -w /workspace \
#     -e PROXMOX_VE_ENDPOINT="https://..." \
#     -e PROXMOX_VE_API_TOKEN='root@pam!token=...' \
#     pdcs-core-tf-modules:latest terragrunt run --all apply

FROM debian:bookworm-slim

ARG TOFU_VERSION=1.12.5
ARG TERRAGRUNT_VERSION=1.2.1

# ---------------------------------------------------------------------------
# Proxy at build time
# ---------------------------------------------------------------------------
# Docker BuildKit automatically injects the client proxy env vars
# (HTTP_PROXY / HTTPS_PROXY / NO_PROXY / ALL_PROXY and lowercase variants),
# taken from the shell, ~/.docker/config.json or Docker Desktop settings.
# apt-get and curl then go through that proxy by surprise, and the build
# commonly fails with "exit code 100" (E: Unable to locate package ...).
#
# We neutralize the ambient proxy UNLESS BUILD_USE_PROXY=true is passed.
# ---------------------------------------------------------------------------
ARG BUILD_USE_PROXY=false

ENV DEBIAN_FRONTEND=noninteractive

RUN if [ "$BUILD_USE_PROXY" != "true" ]; then \
      unset HTTP_PROXY HTTPS_PROXY ALL_PROXY http_proxy https_proxy all_proxy; \
    fi \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        openssh-client \
        unzip \
    && rm -rf /var/lib/apt/lists/*

# Install OpenTofu (multi-arch aware)
RUN if [ "$BUILD_USE_PROXY" != "true" ]; then \
      unset HTTP_PROXY HTTPS_PROXY ALL_PROXY http_proxy https_proxy all_proxy; \
    fi \
    && ARCH=$(uname -m) \
    && case "$ARCH" in \
         x86_64) TOFU_ARCH=amd64 ;; \
         aarch64|arm64) TOFU_ARCH=arm64 ;; \
         *) echo "Unsupported architecture: $ARCH" >&2; exit 1 ;; \
       esac \
    && curl -fsSL "https://github.com/opentofu/opentofu/releases/download/v${TOFU_VERSION}/tofu_${TOFU_VERSION}_linux_${TOFU_ARCH}.zip" -o /tmp/tofu.zip \
    && unzip -o /tmp/tofu.zip -d /usr/local/bin \
    && rm -f /tmp/tofu.zip \
    && tofu version

# Install Terragrunt (multi-arch aware)
RUN if [ "$BUILD_USE_PROXY" != "true" ]; then \
      unset HTTP_PROXY HTTPS_PROXY ALL_PROXY http_proxy https_proxy all_proxy; \
    fi \
    && ARCH=$(uname -m) \
    && case "$ARCH" in \
         x86_64) TG_ARCH=amd64 ;; \
         aarch64|arm64) TG_ARCH=arm64 ;; \
         *) echo "Unsupported architecture: $ARCH" >&2; exit 1 ;; \
       esac \
    && curl -fsSL "https://github.com/gruntwork-io/terragrunt/releases/download/v${TERRAGRUNT_VERSION}/terragrunt_linux_${TG_ARCH}" -o /usr/local/bin/terragrunt \
    && chmod +x /usr/local/bin/terragrunt \
    && terragrunt --version

WORKDIR /workspace

COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["tofu"]
