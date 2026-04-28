variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the existing resource group (created by bootstrap)"
  type        = string
}

variable "project" {
  description = "Project name; used in resource names and tags"
  type        = string
}

variable "environment" {
  description = "Environment name used for tagging (e.g. production, staging)"
  type        = string
}

# ── Networking ───────────────────────────────────────────────────────────────

variable "vnet_address_space" {
  description = "CIDR block for the virtual network"
  type        = string
  default     = "10.0.0.0/16"
}

variable "aks_subnet_prefix" {
  description = "CIDR block for the AKS node subnet"
  type        = string
  default     = "10.0.0.0/22"
}

variable "db_subnet_prefix" {
  description = "CIDR block for the managed databases subnet (delegated to PostgreSQL Flexible Server)"
  type        = string
  default     = "10.0.4.0/24"
}

variable "pe_subnet_prefix" {
  description = "CIDR block for the private endpoints subnet"
  type        = string
  default     = "10.0.5.0/24"
}

# ── Storage ──────────────────────────────────────────────────────────────────

variable "adls_storage_account_name" {
  description = "Globally unique name for the ADLS Gen2 storage account (hierarchical namespace)"
  type        = string
}

variable "blob_storage_account_name" {
  description = "Globally unique name for the Blob Storage account (operational data, GRS)"
  type        = string
}

# ── Key Vault ────────────────────────────────────────────────────────────────

variable "keyvault_name" {
  description = "Globally unique name for the Azure Key Vault"
  type        = string
}

variable "keyvault_admin_object_ids" {
  description = "List of Azure AD object IDs granted Key Vault Secrets Officer (e.g. developer accounts). The Terraform execution identity is always granted Administrator separately."
  type        = list(string)
  default     = []
}

# ── Database ─────────────────────────────────────────────────────────────────

variable "postgres_admin_username" {
  description = "Administrator username for the PostgreSQL Flexible Server"
  type        = string
}

# ── AKS ──────────────────────────────────────────────────────────────────────

variable "aks_kubernetes_version" {
  description = "Kubernetes version for the AKS cluster (null = latest stable)"
  type        = string
  default     = null
}

variable "aks_system_vm_size" {
  description = "VM size for the system node pool"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "aks_system_node_count" {
  description = "Fixed node count for the system node pool"
  type        = number
  default     = 2
}

variable "aks_spark_vm_size" {
  description = "VM size for the Spark node pool (memory-optimized recommended)"
  type        = string
  default     = "Standard_E4s_v3"
}

variable "aks_spark_min_count" {
  description = "Minimum node count for the Spark autoscaling node pool (0 = scales to zero when idle)"
  type        = number
  default     = 0
}

variable "aks_spark_max_count" {
  description = "Maximum node count for the Spark autoscaling node pool"
  type        = number
  default     = 3
}

variable "api_server_authorized_ip_ranges" {
  description = <<-EOT
    List of CIDR ranges allowed to reach the AKS API server.
    Must include the operator's public IP and all CI/CD runner IP ranges.
    GitHub Actions IP ranges can be found at https://api.github.com/meta (hooks key).
  EOT
  type        = list(string)
}

# ── ACR ──────────────────────────────────────────────────────────────────────

variable "acr_name" {
  description = "Globally unique name for the Azure Container Registry"
  type        = string
}

# ── GitHub Actions OIDC ──────────────────────────────────────────────────────

variable "github_org" {
  description = "GitHub organization or user name that owns the repository"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name (without the org prefix)"
  type        = string
}
