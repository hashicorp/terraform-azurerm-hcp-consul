# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0


data "azurerm_subscription" "current" {}

resource "random_string" "vm_admin_password" {
  length = 16
}

resource "azurerm_resource_group" "rg" {
  name     = "${var.cluster_id}-gid"
  location = var.network_region
}

resource "azurerm_route_table" "rt" {
  name                = "${var.cluster_id}-rt"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
}

resource "azurerm_network_security_group" "nsg" {
  name                = "${var.cluster_id}-nsg"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
}

module "network" {
  source  = "Azure/vnet/azurerm"
  version = "~> 3.0"

  resource_group_name = azurerm_resource_group.rg.name
  address_space       = var.vnet_cidrs
  subnet_prefixes     = values(var.vnet_subnets)
  subnet_names        = keys(var.vnet_subnets)
  use_for_each        = true
  vnet_location       = azurerm_resource_group.rg.location
  vnet_name           = "${var.cluster_id}-vnet"

  # Every subnet will share a single route table
  route_tables_ids = { for i, subnet in keys(var.vnet_subnets) : subnet => azurerm_route_table.rt.id }

  # Every subnet will share a single network security group
  nsg_ids = { for i, subnet in keys(var.vnet_subnets) : subnet => azurerm_network_security_group.nsg.id }

  depends_on = [azurerm_resource_group.rg]
}

resource "hcp_hvn" "hvn" {
  hvn_id         = var.hvn_id
  cloud_provider = "azure"
  region         = var.hvn_region
  cidr_block     = var.hvn_cidr_block
}

module "hcp_peering" {
  source  = "hashicorp/hcp-consul/azurerm"
  version = "~> 0.3.2"

  # Required
  tenant_id       = data.azurerm_subscription.current.tenant_id
  subscription_id = data.azurerm_subscription.current.subscription_id
  hvn             = hcp_hvn.hvn
  vnet_rg         = azurerm_resource_group.rg.name
  vnet_id         = module.network.vnet_id
  subnet_ids      = module.network.vnet_subnets

  # Optional
  security_group_names = [azurerm_network_security_group.nsg.name]
  prefix               = var.cluster_id
}

resource "hcp_consul_cluster" "main" {
  cluster_id      = var.cluster_id
  hvn_id          = hcp_hvn.hvn.hvn_id
  public_endpoint = true
  tier            = var.tier
}

resource "hcp_consul_cluster_root_token" "token" {
  cluster_id = hcp_consul_cluster.main.id
}

module "vm_client" {
  source  = "hashicorp/hcp-consul/azurerm//modules/hcp-vm-client"
  version = "~> 0.3.2"

  resource_group = azurerm_resource_group.rg.name
  location       = azurerm_resource_group.rg.location

  nsg_name                 = azurerm_network_security_group.nsg.name
  allowed_ssh_cidr_blocks  = ["0.0.0.0/0"]
  allowed_http_cidr_blocks = ["0.0.0.0/0"]
  subnet_id                = module.network.vnet_subnets[0]

  vm_admin_password = random_string.vm_admin_password.result

  client_config_file = hcp_consul_cluster.main.consul_config_file
  client_ca_file     = hcp_consul_cluster.main.consul_ca_file
  root_token         = hcp_consul_cluster_root_token.token.secret_id
  consul_version     = hcp_consul_cluster.main.consul_version
}
