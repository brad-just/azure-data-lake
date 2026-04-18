# ── ADLS Gen2 (Iceberg data) ──────────────────────────────────────────────────

resource "azurerm_storage_account" "adls" {
  name                            = var.adls_storage_account_name
  resource_group_name             = data.azurerm_resource_group.main.name
  location                        = data.azurerm_resource_group.main.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  account_kind                    = "StorageV2"
  is_hns_enabled                  = true  # hierarchical namespace = ADLS Gen2
  allow_nested_items_to_be_public = false
  # Public access left enabled so Terraform can manage filesystems from outside
  # the VNet. In-cluster traffic uses the private endpoint. Harden for production
  # by adding an ip_rules allowlist or deploying Terraform from within the VNet.

  tags = local.tags
}

resource "azurerm_storage_data_lake_gen2_filesystem" "iceberg_raw" {
  name               = "iceberg-raw"
  storage_account_id = azurerm_storage_account.adls.id
}

resource "azurerm_storage_data_lake_gen2_filesystem" "iceberg_curated" {
  name               = "iceberg-curated"
  storage_account_id = azurerm_storage_account.adls.id
}

# ── Blob Storage (operational / Airbyte) ─────────────────────────────────────

resource "azurerm_storage_account" "blob" {
  name                            = var.blob_storage_account_name
  resource_group_name             = data.azurerm_resource_group.main.name
  location                        = data.azurerm_resource_group.main.location
  account_tier                    = "Standard"
  account_replication_type        = "GRS"
  account_kind                    = "StorageV2"
  allow_nested_items_to_be_public = false
  # Same as ADLS account — public access enabled for Terraform runner access.

  tags = local.tags
}

resource "azurerm_storage_container" "airbyte_logs" {
  name                  = "airbyte-logs"
  storage_account_id    = azurerm_storage_account.blob.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "airbyte_state" {
  name                  = "airbyte-state"
  storage_account_id    = azurerm_storage_account.blob.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.blob.id
  container_access_type = "private"
}
