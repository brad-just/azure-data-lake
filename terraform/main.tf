terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  backend "azurerm" {
    container_name = "tfstate"
    key            = "datalake.tfstate"
    # resource_group_name and storage_account_name are supplied via -backend-config flags
    # (or TF_BACKEND_RESOURCE_GROUP / TF_BACKEND_STORAGE_ACCOUNT env vars in CI).
    # Run bootstrap/ first so this storage account exists before terraform init.
  }
}

provider "azurerm" {
  subscription_id                 = var.subscription_id
  resource_provider_registrations = "none"
  features {
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
  }
}

provider "azuread" {}

data "azurerm_client_config" "current" {}

locals {
  tags = {
    environment = var.environment
    project     = var.project
    managed-by  = "terraform"
  }
}
