locals {
  # Setting vars as locals for portability to hcp-ui-rgs
  network_region = var.network_region
  hvn_region     = var.hvn_region
  hvn_id         = var.hvn_id
  cluster_id     = var.cluster_id
  vnet_cidrs     = var.vnet_cidrs
  vnet_subnets   = var.vnet_subnets
}

data "azurerm_subscription" "current" {}

# Parent resource group
resource "azurerm_resource_group" "rg" {
  name     = "${local.cluster_id}-gid"
  location = local.network_region
}

resource "azurerm_route_table" "rt" {
  name                = "${local.cluster_id}-rt"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
}

resource "azurerm_network_security_group" "nsg" {
  name                = "${local.cluster_id}-nsg"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
}


# Step 1: Create vnet and subnets
module "network" {
  source              = "Azure/vnet/azurerm"
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = local.vnet_cidrs
  subnet_prefixes     = values(local.vnet_subnets)
  subnet_names        = keys(local.vnet_subnets)
  vnet_name           = "${local.cluster_id}-vnet"

  # Every subnet will share a single route table
  route_tables_ids = { for i, subnet in keys(local.vnet_subnets) : subnet => azurerm_route_table.rt.id }

  # Every subnet will share a single network security group
  nsg_ids = { for i, subnet in keys(local.vnet_subnets) : subnet => azurerm_network_security_group.nsg.id }

  depends_on = [azurerm_resource_group.rg]
}

# Step 1: Create HVN
resource "hcp_hvn" "hvn" {
  hvn_id         = local.hvn_id
  cloud_provider = "azure"
  region         = local.hvn_region
  cidr_block     = "172.25.16.0/20"
}


# Step 2: Create a peering between the HVN and the Vnet. Return a NSG and ASG (security groups)
module "hcp_peering" {
  source = "../../"
  # Required
  tenant_id       = data.azurerm_subscription.current.tenant_id
  subscription_id = data.azurerm_subscription.current.subscription_id
  hvn             = hcp_hvn.hvn
  vnet_rg         = azurerm_resource_group.rg.name
  vnet_id         = module.network.vnet_id
  subnet_ids      = module.network.vnet_subnets
  prefix          = var.cluster_id

  # Optional
  security_group_names = [azurerm_network_security_group.nsg.name]
}

# Step 2: create a consul cluster
resource "hcp_consul_cluster" "main" {
  cluster_id      = var.cluster_id
  hvn_id          = hcp_hvn.hvn.hvn_id
  public_endpoint = true
  tier            = var.tier
}

resource "hcp_consul_cluster_root_token" "token" {
  cluster_id = hcp_consul_cluster.main.id
}

# Step 3: Create a vm that runs nomad and consul and registers some services
module "vm_client" {
  source = "../../modules/hcp-vm-client"

  resource_group = azurerm_resource_group.rg.name
  location       = azurerm_resource_group.rg.location

  nsg_name                 = azurerm_network_security_group.nsg.name
  allowed_ssh_cidr_blocks  = ["0.0.0.0/0"]
  allowed_http_cidr_blocks = ["0.0.0.0/0"]
  subnet_id                = module.network.vnet_subnets[0]

  client_config_file = hcp_consul_cluster.main.consul_config_file
  client_ca_file     = hcp_consul_cluster.main.consul_ca_file
  root_token         = hcp_consul_cluster_root_token.token.secret_id
  consul_version     = hcp_consul_cluster.main.consul_version
}
