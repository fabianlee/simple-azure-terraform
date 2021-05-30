
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
  tenant_id       = var.azure_tenant_id
  client_id       = var.azure_client_id

  # for Service Principal using password for auth
  client_secret   = var.azure_client_secret

  # for Service Principal using pfx certificate for auth
  # az ad sp credential reset --name $appUri --cert @azure_rsa.crt
  #client_certificate_path = "azure_rsa.pfx"
}
