data "azurerm_subscription" "current" {}

resource "azurerm_resource_group" "rg" {
  location = var.network_region
  name     = "${var.cluster_id}-gid"
}

resource "azurerm_network_security_group" "nsg" {
  location            = azurerm_resource_group.rg.location
  name                = "${var.cluster_id}-nsg"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_virtual_network" "network" {
  address_space       = var.vnet_cidrs
  location            = azurerm_resource_group.rg.location
  name                = "${var.cluster_id}-vnet"
  resource_group_name = azurerm_resource_group.rg.name

  dynamic "subnet" {
    for_each = var.vnet_subnets

    content {
      name           = subnet.key
      address_prefix = subnet.value
      security_group = azurerm_network_security_group.nsg.id
    }
  }
}

resource "azurerm_route_table" "rt" {
  location            = azurerm_resource_group.rg.location
  name                = "${var.cluster_id}-rt"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet_route_table_association" "association" {
  count          = length(azurerm_virtual_network.network.subnet)
  subnet_id      = tolist(azurerm_virtual_network.network.subnet)[count.index].id
  route_table_id = azurerm_route_table.rt.id
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
  subnet_ids           = [for s in azurerm_virtual_network.network.subnet : s.id]
  subscription_id      = data.azurerm_subscription.current.subscription_id
  tenant_id            = data.azurerm_subscription.current.tenant_id
  vnet_id              = azurerm_virtual_network.network.id
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

resource "random_password" "password" {
  length = 32
}

resource "azurerm_kubernetes_cluster" "main" {
  dns_prefix              = var.cluster_id
  location                = azurerm_resource_group.rg.location
  name                    = var.cluster_id
  private_cluster_enabled = false
  resource_group_name     = azurerm_resource_group.rg.name
  sku_tier                = "Free"

  default_node_pool {
    enable_auto_scaling   = true
    enable_node_public_ip = true
    max_count             = 2
    max_pods              = 100
    min_count             = 1
    name                  = "nodepool"
    os_disk_size_gb       = 50
    vm_size               = "Standard_DS2_v2"
    vnet_subnet_id        = tolist(azurerm_virtual_network.network.subnet)[0].id
  }

  service_principal {
    client_id     = var.cluster_id
    client_secret = random_password.password.result
  }

  network_profile {
    docker_bridge_cidr = "170.10.0.1/16"
    dns_service_ip     = "11.0.0.10"
    load_balancer_sku  = "standard"
    network_plugin     = "kubenet"
    service_cidr       = "11.0.0.0/24"
  }
}

module "aks_consul_client" {
  #source  = "hashicorp/hcp-consul/azurerm//modules/hcp-aks-client"
  #version = "~> X.X.X"
  # TODO: Revert to above once this is published
  source = "../../modules/hcp-aks-client"

  cluster_id       = hcp_consul_cluster.main.cluster_id
  consul_hosts     = jsondecode(base64decode(hcp_consul_cluster.main.consul_config_file))["retry_join"]
  consul_version   = hcp_consul_cluster.main.consul_version
  k8s_api_endpoint = azurerm_kubernetes_cluster.main.kube_config.0.host

  boostrap_acl_token    = hcp_consul_cluster_root_token.token.secret_id
  consul_ca_file        = base64decode(hcp_consul_cluster.main.consul_ca_file)
  datacenter            = hcp_consul_cluster.main.datacenter
  gossip_encryption_key = jsondecode(base64decode(hcp_consul_cluster.main.consul_config_file))["encrypt"]

  # The AKS node group will fail to create if the clients are
  # created at the same time. This forces the client to wait until
  # the node group is successfully created.
  depends_on = [azurerm_kubernetes_cluster.main]
}

module "demo_app" {
  source = "../../modules/k8s-demo-app"
  # source  = "hashicorp/hcp-consul/azurerm//modules/k8s-demo-app"
  # version = "~> X.X.X"

  depends_on = [module.aks_consul_client]
}
