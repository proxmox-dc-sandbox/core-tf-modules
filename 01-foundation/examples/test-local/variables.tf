# ---------------------------------------------------------------------------
# Provider connection settings for the local example.
# The module itself does not declare any of these variables.
# ---------------------------------------------------------------------------
variable "proxmox_endpoint" {
  description = "Proxmox API endpoint (overrides PROXMOX_VE_ENDPOINT when set)."
  type        = string
  default     = null
}

variable "proxmox_api_token" {
  description = "Proxmox API token (overrides PROXMOX_VE_API_TOKEN when set)."
  type        = string
  default     = null
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "Skip TLS verification for the Proxmox API."
  type        = bool
  default     = true
}

variable "proxmox_ssh_agent" {
  description = "Use the SSH agent instead of a private key file."
  type        = bool
  default     = false
}

variable "proxmox_ssh_username" {
  description = "SSH user used to upload snippets (cloud-init)."
  type        = string
  default     = "root"
}

variable "proxmox_ssh_private_key" {
  description = "Path to the SSH private key (mounted in the container, e.g. /workspace/id_rsa)."
  type        = string
  default     = "/workspace/id_rsa"
}

variable "proxmox_ssh_node_name" {
  description = "Proxmox node name used for SSH operations."
  type        = string
  default     = "pve"
}

variable "proxmox_ssh_address" {
  description = "Node IP used for SSH (required by the provider; used for snippet uploads)."
  type        = string
}

variable "proxmox_ssh_socks5_server" {
  description = "SOCKS5 proxy for the provider's SSH connections (address:port)."
  type        = string
  default     = null
  sensitive   = true
}

variable "proxmox_ssh_socks5_username" {
  description = "SOCKS5 proxy username (optional)."
  type        = string
  default     = null
  sensitive   = true
}

variable "proxmox_ssh_socks5_password" {
  description = "SOCKS5 proxy password (optional)."
  type        = string
  default     = null
  sensitive   = true
}

variable "proxmox_ssh_node_address_source" {
  description = "How the provider resolves the node IP for SSH: \"api\" or \"dns\"."
  type        = string
  default     = "api"
}
