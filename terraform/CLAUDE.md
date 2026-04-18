# Terraform — Context

@../CLAUDE.md

---

## Bootstrap requirement

The azurerm remote state backend depends on a storage account and container that must exist before `terraform init` can run. This is a chicken-and-egg problem. Produce a `bootstrap/` directory with a minimal, separate Terraform config (no remote backend) that creates only:
- The resource group
- The storage account and `tfstate` container for remote state

The README must document running bootstrap first, then initializing the main config.

---

## Backend config

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = var.resource_group_name
    storage_account_name = var.tfstate_storage_account
    container_name       = "tfstate"
    key                  = "datalake.tfstate"
  }
}
```

Backend values (storage account name, resource group) are passed via GitHub Actions secrets, not committed to the repo.

---

## Required resources

### Networking (`networking.tf`)
- Resource group
- VNet with subnets: AKS nodes, managed databases, private endpoints
- NSGs with least-privilege rules
- Private endpoints for: ADLS Gen2, Blob Storage, PostgreSQL
- Key Vault (store all generated credentials here)

### Storage (`storage.tf`)
- ADLS Gen2 storage account — hierarchical namespace enabled
  - Containers: `iceberg-raw`, `iceberg-curated`
- Blob Storage account — Standard GRS
  - Containers: `airbyte-logs`, `airbyte-state`, `tfstate`

### Database (`database.tf`)
- PostgreSQL Flexible Server
  - Databases: `airbyte_db`, `nessie_db`, `superset_db`, `airflow_db`
  - Generated password stored in Key Vault

### AKS (`aks.tf`)
- System node pool: standard VM size
- Spark node pool: memory-optimized, autoscaling enabled
- Workload identity enabled, OIDC issuer enabled
- Add-ons: `azure-keyvault-secrets-provider`, `secrets-store-csi-driver`
- **Public cluster** — API server has a public endpoint; do not set `private_cluster_enabled = true`
- Restrict API server access via `api_server_authorized_ip_ranges`:
  - Accept a variable `api_server_authorized_ip_ranges` (list of CIDRs, no default — must be explicitly set)
  - GitHub Actions IP ranges should be included — fetch from `https://api.github.com/meta` or accept as a variable input
  - Document in `terraform.tfvars.example` that this must include the operator's IP and any CI/CD runner IPs

### IAM (`iam.tf`)
- AKS managed identity: Storage Blob Data Contributor on both storage accounts
- AKS managed identity: Key Vault Secrets User
- GitHub Actions service principal:
  - Contributor on resource group
  - Key Vault Secrets Officer on Key Vault
  - AcrPush on ACR
  - Federated credential scoped to the GitHub repo — parameterize org and repo name via variables

### ACR (`acr.tf`)
- Azure Container Registry
- AKS managed identity: AcrPull

---

## Required outputs

```
aks_kubeconfig
adls_storage_account_name
blob_storage_account_name
postgres_fqdn
nessie_service_url         # placeholder — actual value set post-Helm deploy
acr_login_server
keyvault_uri
github_actions_client_id   # for OIDC setup in GitHub secrets
```

---

## Variable conventions
- No default values for sensitive or environment-specific variables (region, subscription_id, resource_group_name, postgres_admin_password)
- Provide a `variables.tf` with descriptions for every variable
- Provide a `terraform.tfvars.example` with placeholder values and comments