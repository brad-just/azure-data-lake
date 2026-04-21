resource "azurerm_key_vault" "main" {
  name                       = var.keyvault_name
  location                   = data.azurerm_resource_group.main.location
  resource_group_name        = data.azurerm_resource_group.main.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true
  purge_protection_enabled   = false
  soft_delete_retention_days = 7

  network_acls {
    default_action = "Allow"
    bypass         = "AzureServices"
  }

  tags = local.tags
}

# Grant the Terraform execution identity Key Vault Administrator so it can
# write secrets during apply.
resource "azurerm_role_assignment" "keyvault_terraform_admin" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Grant developer accounts Secrets Officer so they can read/write secrets
# without needing full Administrator. Add object IDs to keyvault_admin_object_ids
# in tfvars: run `az ad signed-in-user show --query id -o tsv` to find yours.
resource "azurerm_role_assignment" "keyvault_admin_users" {
  for_each             = toset(var.keyvault_admin_object_ids)
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = each.value
}
