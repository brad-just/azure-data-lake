output "resource_group_name" {
  description = "Name of the created resource group"
  value       = azurerm_resource_group.main.name
}

output "tfstate_storage_account_name" {
  description = "Name of the storage account for Terraform remote state"
  value       = azurerm_storage_account.tfstate.name
}

output "tfstate_container_name" {
  description = "Name of the blob container for Terraform state files"
  value       = azurerm_storage_container.tfstate.name
}
