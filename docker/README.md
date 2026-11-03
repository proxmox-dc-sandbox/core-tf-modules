# Docker runner image

This directory contains the Dockerfile and entrypoint for the OpenTofu +
Terragrunt runner image.

```shell
docker build -f docker/Dockerfile -t pdcs-core-tf-modules:latest .
```

The image contains OpenTofu (default `1.12.5`) and Terragrunt (default
`1.2.1`), plus proxy support for API, registry and SSH traffic.

Usage, proxy configuration, SOCKS5, SSH jump hosts and build troubleshooting are
documented in [../docs/docker.md](../docs/docker.md). The `terragrunt-docker.sh`
wrapper at the repository root provides the recommended client workflow.
