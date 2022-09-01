data "azurerm_subscription" "current" {}

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
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Create an Azure vnet and authorize Consul server traffic.
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

# Create an HCP HVN.
resource "hcp_hvn" "hvn" {
  cidr_block     = var.hvn_cidr_block
  cloud_provider = "azure"
  hvn_id         = var.hvn_id
  region         = var.hvn_region
}

# Peer the HVN to the vnet.
module "hcp_peering" {
  source  = "hashicorp/hcp-consul/azurerm"
  version = "~> 0.2.7"

  hvn    = hcp_hvn.hvn
  prefix = var.cluster_id

  security_group_names = [azurerm_network_security_group.nsg.name]
  subscription_id      = data.azurerm_subscription.current.subscription_id
  tenant_id            = data.azurerm_subscription.current.tenant_id

  subnet_ids = module.network.vnet_subnets
  vnet_id    = module.network.vnet_id
  vnet_rg    = azurerm_resource_group.rg.name
}

# Create the Consul cluster.
resource "hcp_consul_cluster" "main" {
  cluster_id      = var.cluster_id
  hvn_id          = hcp_hvn.hvn.hvn_id
  public_endpoint = true
  tier            = var.tier
}

resource "hcp_consul_cluster_root_token" "token" {
  cluster_id = hcp_consul_cluster.main.id
}

# Create a user assigned identity (required for UserAssigned identity in combination with brining our own subnet/nsg/etc)
resource "azurerm_user_assigned_identity" "identity" {
  name                = "aks-identity"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Create the AKS cluster.
resource "azurerm_kubernetes_cluster" "k8" {
  name                    = var.cluster_id
  dns_prefix              = var.cluster_id
  location                = azurerm_resource_group.rg.location
  private_cluster_enabled = false
  resource_group_name     = azurerm_resource_group.rg.name

  network_profile {
    network_plugin     = "azure"
    service_cidr       = "10.30.0.0/16"
    dns_service_ip     = "10.30.0.10"
    docker_bridge_cidr = "172.17.0.1/16"
  }

  default_node_pool {
    name            = "default"
    node_count      = 3
    vm_size         = "Standard_D2_v2"
    os_disk_size_gb = 30
    pod_subnet_id   = module.network.vnet_subnets[0]
    vnet_subnet_id  = module.network.vnet_subnets[1]
  }

  identity {
    type                      = "UserAssigned"
    user_assigned_identity_id = azurerm_user_assigned_identity.identity.id
  }

  depends_on = [module.network]
}

# Create a Kubernetes client that deploys Consul and its secrets.
module "aks_consul_client" {
  source  = "hashicorp/hcp-consul/azurerm//modules/hcp-aks-client"
  version = "~> 0.2.7"

  cluster_id       = hcp_consul_cluster.main.cluster_id
  consul_hosts     = jsondecode(base64decode(hcp_consul_cluster.main.consul_config_file))["retry_join"]
  consul_version   = hcp_consul_cluster.main.consul_version
  k8s_api_endpoint = azurerm_kubernetes_cluster.k8.kube_config.0.host

  boostrap_acl_token    = hcp_consul_cluster_root_token.token.secret_id
  consul_ca_file        = base64decode(hcp_consul_cluster.main.consul_ca_file)
  datacenter            = hcp_consul_cluster.main.datacenter
  gossip_encryption_key = jsondecode(base64decode(hcp_consul_cluster.main.consul_config_file))["encrypt"]

  # The AKS node group will fail to create if the clients are
  # created at the same time. This forces the client to wait until
  # the node group is successfully created.
  depends_on = [azurerm_kubernetes_cluster.k8]
}

# Deploy Hashicups.
module "demo_app" {
  source  = "hashicorp/hcp-consul/azurerm//modules/k8s-demo-app"
  version = "~> 0.2.7"

  depends_on = [module.aks_consul_client]
}

# Authorize HTTP ingress to the load balancer.
resource "azurerm_network_security_rule" "ingress" {
  name                        = "http-ingress"
  priority                    = 301
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = module.demo_app.load_balancer_ip
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg.name

  depends_on = [module.demo_app]
}
