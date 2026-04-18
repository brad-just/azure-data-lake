output "aks_kubeconfig" {
  description = "Raw kubeconfig for the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.kube_config_raw
  sensitive   = true
}

output "adls_storage_account_name" {
  description = "Name of the ADLS Gen2 storage account (Iceberg data)"
  value       = azurerm_storage_account.adls.name
}

output "blob_storage_account_name" {
  description = "Name of the Blob Storage account (Airbyte logs and state)"
  value       = azurerm_storage_account.blob.name
}

output "postgres_fqdn" {
  description = "Fully qualified domain name of the PostgreSQL Flexible Server"
  value       = azurerm_postgresql_flexible_server.main.fqdn
}

output "nessie_service_url" {
  description = "Nessie REST catalog URL — placeholder until Helm deploy sets the in-cluster service"
  value       = "http://nessie.nessie.svc.cluster.local/api/v1"
}

output "acr_login_server" {
  description = "Login server hostname for Azure Container Registry"
  value       = azurerm_container_registry.main.login_server
}

output "keyvault_uri" {
  description = "URI of the Azure Key Vault"
  value       = azurerm_key_vault.main.vault_uri
}

output "github_actions_client_id" {
  description = "Client ID of the GitHub Actions Azure AD application — set as AZURE_CLIENT_ID in GitHub secrets"
  value       = azuread_application.github_actions.client_id
}

output "aks_oidc_issuer_url" {
  description = "OIDC issuer URL for the AKS cluster — used when configuring workload identity federated credentials"
  value       = azurerm_kubernetes_cluster.main.oidc_issuer_url
}
