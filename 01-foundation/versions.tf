# ---------------------------------------------------------------------------
# Provider requirements only.
#
# No provider block here on purpose: credentials, endpoint and SSH settings
# are supplied by the caller (Terragrunt generate block or examples/).
# No backend either: state configuration is generated client-side.
# ---------------------------------------------------------------------------
terraform {
  required_version = ">= 1.8.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.116.0, < 1.0.0"
    }
  }
}
