resource "random_password" "postgres" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "azurerm_postgresql_flexible_server" "main" {
  name                   = "${var.project}-postgres"
  location               = data.azurerm_resource_group.main.location
  resource_group_name    = data.azurerm_resource_group.main.name
  version                = "16"
  administrator_login    = var.postgres_admin_username
  administrator_password = random_password.postgres.result

  # VNet integration — server lives inside the delegated database subnet.
  # No separate private endpoint needed; connectivity is via the subnet.
  delegated_subnet_id           = azurerm_subnet.database.id
  private_dns_zone_id           = azurerm_private_dns_zone.postgres.id
  public_network_access_enabled = false

  sku_name   = "B_Standard_B2s"
  storage_mb = 32768

  backup_retention_days        = 7
  geo_redundant_backup_enabled = false

  authentication {
    active_directory_auth_enabled = false
    password_auth_enabled         = true
  }

  tags = local.tags

  depends_on = [azurerm_private_dns_zone_virtual_network_link.postgres]

  lifecycle {
    ignore_changes = [zone]
  }
}

# btree_gin is required by Temporal (bundled with Airbyte). Azure PostgreSQL
# Flexible Server blocks extensions by default — they must be allowlisted here
# before any client can run CREATE EXTENSION.
resource "azurerm_postgresql_flexible_server_configuration" "extensions" {
  name      = "azure.extensions"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "BTREE_GIN"
}

resource "azurerm_postgresql_flexible_server_database" "airbyte" {
  name      = "airbyte_db"
  server_id = azurerm_postgresql_flexible_server.main.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

resource "azurerm_postgresql_flexible_server_database" "nessie" {
  name      = "nessie_db"
  server_id = azurerm_postgresql_flexible_server.main.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

resource "azurerm_postgresql_flexible_server_database" "superset" {
  name      = "superset_db"
  server_id = azurerm_postgresql_flexible_server.main.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

resource "azurerm_postgresql_flexible_server_database" "airflow" {
  name      = "airflow_db"
  server_id = azurerm_postgresql_flexible_server.main.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

resource "azurerm_key_vault_secret" "postgres_password" {
  name         = "postgres-admin-password"
  value        = random_password.postgres.result
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_role_assignment.keyvault_terraform_admin]
}

resource "azurerm_key_vault_secret" "postgres_fqdn" {
  name         = "postgres-fqdn"
  value        = azurerm_postgresql_flexible_server.main.fqdn
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_role_assignment.keyvault_terraform_admin]
}

# Import block for secrets that were created manually before Terraform managed them.
# Remove these import blocks after the first successful apply.
import {
  to = azurerm_key_vault_secret.nessie_jdbc_url
  id = "https://kv-datalake-prod02.vault.azure.net/secrets/nessie-jdbc-url/bdedcca458b042f1ab8ff45444124e9d"
}

import {
  to = azurerm_key_vault_secret.airflow_db_uri
  id = "https://kv-datalake-prod02.vault.azure.net/secrets/airflow-db-uri/6391658913af49ddb0bda26886ec2e8a"
}

resource "azurerm_key_vault_secret" "nessie_jdbc_url" {
  name         = "nessie-jdbc-url"
  value        = "jdbc:postgresql://${azurerm_postgresql_flexible_server.main.fqdn}:5432/nessie_db?sslmode=require"
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_role_assignment.keyvault_terraform_admin]
}

resource "azurerm_key_vault_secret" "airflow_db_uri" {
  name         = "airflow-db-uri"
  value        = "postgresql+psycopg2://${var.postgres_admin_username}:${random_password.postgres.result}@${azurerm_postgresql_flexible_server.main.fqdn}:5432/airflow_db?sslmode=require"
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_role_assignment.keyvault_terraform_admin]
}
