locals {
  hvn_region      = "{{ .HVNRegion }}"
  hvn_id          = "{{ .ClusterID }}-hvn"
  cluster_id      = "{{ .ClusterID }}"
  subscription_id = "{{ .SubscriptionID }}"
  vnet_rg_name    = "{{ .VnetRgName }}"
  vnet_id         = "/subscriptions/{{ .SubscriptionID }}/resourceGroups/{{ .VnetRgName }}/providers/Microsoft.Network/virtualNetworks/{{ .VnetName }}"
  subnet_id       = "/subscriptions/{{ .SubscriptionID }}/resourceGroups/{{ .VnetRgName }}/providers/Microsoft.Network/virtualNetworks/{{ .VnetName }}/subnets/{{ .SubnetName }}"
}


terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.65"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.14"
    }
    hcp = {
      source  = "hashicorp/hcp"
      version = ">= 0.23.1"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 3.4.0"
    }
  }

  required_version = ">= 1.0.11"

}

provider "azurerm" {
  features {}
}

provider "azuread" {}

provider "hcp" {}

provider "tls" {}

provider "consul" {
  address    = hcp_consul_cluster.main.consul_public_endpoint_url
  datacenter = hcp_consul_cluster.main.datacenter
  token      = hcp_consul_cluster_root_token.token.secret_id
}

data "azurerm_subscription" "current" {}

data "azurerm_resource_group" "rg" {
  name = local.vnet_rg_name
}

resource "azurerm_network_security_group" "nsg" {
  name                = "${local.cluster_id}-nsg"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
}

resource "hcp_hvn" "hvn" {
  hvn_id         = local.hvn_id
  cloud_provider = "azure"
  region         = local.hvn_region
  cidr_block     = "172.25.32.0/20"
}

module "hcp_peering" {
  source  = "hashicorp/hcp-consul/azurerm"
  version = "~> 0.2.0"

  # Required
  tenant_id       = data.azurerm_subscription.current.tenant_id
  subscription_id = data.azurerm_subscription.current.subscription_id
  hvn             = hcp_hvn.hvn
  vnet_rg         = data.azurerm_resource_group.rg.name
  vnet_id         = local.vnet_id
  subnet_ids      = [local.subnet_id]

  # Optional
  security_group_names = [azurerm_network_security_group.nsg.name]
  prefix               = local.cluster_id
}

resource "hcp_consul_cluster" "main" {
  cluster_id      = local.cluster_id
  hvn_id          = hcp_hvn.hvn.hvn_id
  public_endpoint = true
  tier            = "development"
}

resource "hcp_consul_cluster_root_token" "token" {
  cluster_id = hcp_consul_cluster.main.id
}

resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

module "vm_client" {
  source  = "hashicorp/hcp-consul/azurerm//modules/hcp-vm-client"
  version = "~> 0.2.0"

  resource_group = data.azurerm_resource_group.rg.name
  location       = data.azurerm_resource_group.rg.location

  nsg_name                 = azurerm_network_security_group.nsg.name
  allowed_ssh_cidr_blocks  = ["0.0.0.0/0"]
  allowed_http_cidr_blocks = ["0.0.0.0/0"]
  subnet_id                = local.subnet_id

  client_config_file = hcp_consul_cluster.main.consul_config_file
  client_ca_file     = hcp_consul_cluster.main.consul_ca_file
  root_token         = hcp_consul_cluster_root_token.token.secret_id
  ssh_public_key     = tls_private_key.ssh.public_key_openssh
  consul_version     = hcp_consul_cluster.main.consul_version
}

output "consul_root_token" {
  value     = hcp_consul_cluster_root_token.token.secret_id
  sensitive = true
}

output "consul_url" {
  value = hcp_consul_cluster.main.consul_public_endpoint_url
}

output "nomad_url" {
  value = "http://${module.vm_client.public_ip}:8081"
}

output "hashicups_url" {
  value = "http://${module.vm_client.public_ip}"
}

output "next_steps" {
  value = "Hashicups Application will be ready in ~5 minutes. Use 'terraform output consul_root_token' to retrieve the root token."
}

output "private_key_openssh" {
  value     = tls_private_key.ssh.private_key_openssh
  sensitive = true
}

output "vm_client_public_ip" {
  value = module.vm_client.public_ip
}
