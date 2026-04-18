variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group to create for the data lake"
  type        = string
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
}

variable "tfstate_storage_account" {
  description = "Globally unique name for the storage account that will hold Terraform remote state"
  type        = string
}

variable "project" {
  description = "Project name used for resource tagging"
  type        = string
}

variable "environment" {
  description = "Environment name used for resource tagging (e.g. production, staging)"
  type        = string
}
