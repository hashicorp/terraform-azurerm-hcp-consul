data "azurerm_subscription" "current" {}

resource "azurerm_resource_group" "rg" {
  location = var.network_region
  name     = "${var.cluster_id}-gid"
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
  source              = "Azure/vnet/azurerm"
  address_space       = var.vnet_cidrs
  resource_group_name = azurerm_resource_group.rg.name
  subnet_names        = keys(var.vnet_subnets)
  subnet_prefixes     = values(var.vnet_subnets)
  vnet_name           = "${var.cluster_id}-vnet"

  # Every subnet will share a single route table
  route_tables_ids = { for i, subnet in keys(var.vnet_subnets) : subnet => azurerm_route_table.rt.id }

  # Every subnet will share a single network security group
  nsg_ids = { for i, subnet in keys(var.vnet_subnets) : subnet => azurerm_network_security_group.nsg.id }

  depends_on = [azurerm_resource_group.rg]
}

resource "hcp_hvn" "hvn" {
  cidr_block     = var.hvn_cidr_block
  cloud_provider = "azure"
  hvn_id         = var.hvn_id
  region         = var.hvn_region
}

module "hcp_peering" {
  #source  = "hashicorp/hcp-consul/azurerm"
  #version = "~> X.X.X"
  # TODO: Revert to above once this is published
  source = "../.."

  hvn                  = hcp_hvn.hvn
  prefix               = var.cluster_id
  security_group_names = [azurerm_network_security_group.nsg.name]
  subnet_ids           = module.network.vnet_subnets
  subscription_id      = data.azurerm_subscription.current.subscription_id
  tenant_id            = data.azurerm_subscription.current.tenant_id
  vnet_id              = module.network.vnet_id
  vnet_rg              = azurerm_resource_group.rg.name
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

module "aks" {
  source                  = "Azure/aks/azurerm"
  version                 = "4.16.0"
  resource_group_name     = azurerm_resource_group.rg.name
  prefix                  = var.cluster_id
  cluster_name            = var.cluster_id
  agents_size             = "standard_d2s_v5"
  network_plugin          = "azure"
  vnet_subnet_id          = module.network.vnet_subnets[0]
  os_disk_size_gb         = 50
  private_cluster_enabled = false

  agents_min_count          = 1
  agents_max_count          = 2
  agents_max_pods           = 100
  agents_pool_name          = "nodepool"
  agents_availability_zones = ["1"]

  sku_tier                       = "Free"
  network_policy                 = "azure"
  net_profile_dns_service_ip     = "10.0.0.10"
  net_profile_docker_bridge_cidr = "170.10.0.1/16"
  net_profile_service_cidr       = "10.0.0.0/24"

  depends_on = [module.network]
}

module "aks_consul_client" {
  #source  = "hashicorp/hcp-consul/azurerm//modules/hcp-aks-client"
  #version = "~> X.X.X"
  # TODO: Revert to above once this is published
  source = "../../modules/hcp-aks-client"

  cluster_id       = hcp_consul_cluster.main.cluster_id
  consul_hosts     = jsondecode(base64decode(hcp_consul_cluster.main.consul_config_file))["retry_join"]
  consul_version   = hcp_consul_cluster.main.consul_version
  k8s_api_endpoint = module.aks.host

  boostrap_acl_token    = hcp_consul_cluster_root_token.token.secret_id
  consul_ca_file        = base64decode(hcp_consul_cluster.main.consul_ca_file)
  datacenter            = hcp_consul_cluster.main.datacenter
  gossip_encryption_key = jsondecode(base64decode(hcp_consul_cluster.main.consul_config_file))["encrypt"]

  # The AKS node group will fail to create if the clients are
  # created at the same time. This forces the client to wait until
  # the node group is successfully created.
  depends_on = [module.aks]
}

module "demo_app" {
  source = "../../modules/k8s-demo-app"
  # source  = "hashicorp/hcp-consul/azurerm//modules/k8s-demo-app"
  # version = "~> X.X.X"

  depends_on = [module.aks_consul_client]
}
