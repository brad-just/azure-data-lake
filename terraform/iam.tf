# ── AKS managed identity — storage access ─────────────────────────────────────
# Grants the AKS kubelet identity (used by node pods) read/write access to
# both storage accounts so Spark can read/write Iceberg tables via workload
# identity delegation.

resource "azurerm_role_assignment" "aks_adls_contributor" {
  scope                = azurerm_storage_account.adls.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}

resource "azurerm_role_assignment" "aks_blob_contributor" {
  scope                = azurerm_storage_account.blob.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}

# ── AKS managed identity — Key Vault access ──────────────────────────────────

resource "azurerm_role_assignment" "aks_keyvault_secrets_user" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}

# ── GitHub Actions service principal (OIDC) ───────────────────────────────────

resource "azuread_application" "github_actions" {
  display_name = "${var.project}-github-actions"
}

resource "azuread_service_principal" "github_actions" {
  client_id = azuread_application.github_actions.client_id
}

# Federated credential for pushes to main and the production environment.
resource "azuread_application_federated_identity_credential" "github_actions_main" {
  application_id = azuread_application.github_actions.id
  display_name   = "github-actions-main"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/main"
}

resource "azuread_application_federated_identity_credential" "github_actions_production" {
  application_id = azuread_application.github_actions.id
  display_name   = "github-actions-production"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${var.github_org}/${var.github_repo}:environment:production"
}

# ── GitHub Actions — Azure role assignments ───────────────────────────────────

resource "azurerm_role_assignment" "github_actions_contributor" {
  scope                = data.azurerm_resource_group.main.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.github_actions.object_id
}

resource "azurerm_role_assignment" "github_actions_keyvault_officer" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = azuread_service_principal.github_actions.object_id
}

resource "azurerm_role_assignment" "github_actions_acr_push" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPush"
  principal_id         = azuread_service_principal.github_actions.object_id
}
