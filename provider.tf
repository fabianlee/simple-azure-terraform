# install azure cli
# https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-windows?tabs=azure-cli
# for linux
# https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-linux?pivots=apt

terraform {
  required_version = ">= 0.14.0"
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "2.59.0"
    }
  }
}

provider "azurerm" {
  # Configuration options
  features {}
  subscription_id = var.azure_subscription_id
  client_id       = var.azure_client_id
  client_secret   = var.azure_client_secret
  #client_certificate_path = var.azure_client_certificate_path
  tenant_id       = var.azure_tenant_id
}
