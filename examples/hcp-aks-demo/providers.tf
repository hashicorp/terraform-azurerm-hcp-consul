terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.65"
      configuration_aliases = [azurerm.azure]
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.14"
    }
    hcp = {
      source  = "hashicorp/hcp"
      version = ">= 0.23.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.4.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.3.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.11.3"
    }
  }

  required_version = ">= 1.0.11"

  provider_meta "hcp" {
    module_name = "hcp-consul"
  }
}

provider "helm" {
  kubernetes {
    host                   = module.aks.host
    client_certificate     = base64decode(module.aks.client_certificate)
    cluster_ca_certificate = base64decode(module.aks.cluster_ca_certificate)
    client_key             = base64decode(module.aks.client_key)
    username               = module.aks.admin_username
    password               = module.aks.admin_password
  }
}

provider "kubernetes" {
  host                   = module.aks.host
  client_certificate     = base64decode(module.aks.client_certificate)
  client_key             = base64decode(module.aks.client_key)
  cluster_ca_certificate = base64decode(module.aks.cluster_ca_certificate)
  username               = module.aks.admin_username
  password               = module.aks.admin_password
}

provider "kubectl" {
  host                   = module.aks.host
  cluster_ca_certificate = base64decode(module.aks.cluster_ca_certificate)
  load_config_file       = false
  username               = module.aks.admin_username
  password               = module.aks.admin_password
}

provider "azurerm" {
  features {}
}

provider "azuread" {}

provider "hcp" {}

provider "consul" {
  address    = hcp_consul_cluster.main.consul_public_endpoint_url
  datacenter = hcp_consul_cluster.main.datacenter
  token      = hcp_consul_cluster_root_token.token.secret_id
}
