locals {
  hvn_region     = "{{ .HVNRegion }}"
  hvn_id         = "{{ .ClusterID }}-hvn"
  cluster_id     = "{{ .ClusterID }}"
  network_region = "{{ .VnetRegion }}"
  vnet_cidrs     = ["10.0.0.0/16"]
  vnet_subnets = {
    "subnet1" = "10.0.1.0/24",
  }
}

terraform {
  required_providers {
    azurerm = {
      source                = "hashicorp/azurerm"
      version               = "~> 2.65"
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

}

provider "helm" {
  kubernetes {
    client_certificate     = base64decode(azurerm_kubernetes_cluster.main.kube_config.0.client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.main.kube_config.0.client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.main.kube_config.0.cluster_ca_certificate)
    host                   = azurerm_kubernetes_cluster.main.kube_config.0.host
    password               = azurerm_kubernetes_cluster.main.kube_config.0.password
    username               = azurerm_kubernetes_cluster.main.kube_config.0.username
  }
}

provider "kubernetes" {
  client_certificate     = base64decode(azurerm_kubernetes_cluster.main.kube_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.main.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.main.kube_config.0.cluster_ca_certificate)
  host                   = azurerm_kubernetes_cluster.main.kube_config.0.host
  password               = azurerm_kubernetes_cluster.main.kube_config.0.password
  username               = azurerm_kubernetes_cluster.main.kube_config.0.username
}

provider "kubectl" {
  client_certificate     = base64decode(azurerm_kubernetes_cluster.main.kube_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.main.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.main.kube_config.0.cluster_ca_certificate)
  host                   = azurerm_kubernetes_cluster.main.kube_config.0.host
  load_config_file       = false
  password               = azurerm_kubernetes_cluster.main.kube_config.0.password
  username               = azurerm_kubernetes_cluster.main.kube_config.0.username
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
data "azurerm_subscription" "current" {}

resource "azurerm_resource_group" "rg" {
  location = local.network_region
  name     = "${local.cluster_id}-gid"
}

resource "azurerm_route_table" "rt" {
  location            = azurerm_resource_group.rg.location
  name                = "${local.cluster_id}-rt"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_network_security_group" "nsg" {
  location            = azurerm_resource_group.rg.location
  name                = "${local.cluster_id}-nsg"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_virtual_network" "network" {
  address_space       = local.vnet_cidrs
  location            = azurerm_resource_group.rg.location
  name                = "${local.cluster_id}-vnet"
  resource_group_name = azurerm_resource_group.rg.name

  dynamic "subnet" {
    for_each = local.vnet_subnets

    content {
      name           = subnet.key
      address_prefix = subnet.value
      security_group = azurerm_network_security_group.nsg.id
    }
  }
}

resource "azurerm_public_ip" "ip" {
  allocation_method   = "Static"
  location            = azurerm_resource_group.rg.location
  ip_version          = "IPv4"
  name                = "${local.cluster_id}-ip"
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "standard"
}

resource "hcp_hvn" "hvn" {
  cidr_block     = "172.25.32.0/20"
  cloud_provider = "azure"
  hvn_id         = local.hvn_id
  region         = local.hvn_region
}

module "hcp_peering" {
  #source  = "hashicorp/hcp-consul/azurerm"
  #version = "~> X.X.X"
  # TODO: Revert to above once this is published
  source = "../.."

  hvn                  = hcp_hvn.hvn
  prefix               = local.cluster_id
  security_group_names = [azurerm_network_security_group.nsg.name]
  subnet_ids           = [for s in azurerm_virtual_network.network.subnet : s.id]
  subscription_id      = data.azurerm_subscription.current.subscription_id
  tenant_id            = data.azurerm_subscription.current.tenant_id
  vnet_id              = azurerm_virtual_network.network.id
  vnet_rg              = azurerm_resource_group.rg.name
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

resource "azurerm_kubernetes_cluster" "main" {
  dns_prefix              = local.cluster_id
  location                = azurerm_resource_group.rg.location
  name                    = local.cluster_id
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

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin     = "kubenet"
    service_cidr       = "11.0.0.0/24"
    docker_bridge_cidr = "170.10.0.1/16"
    dns_service_ip     = "11.0.0.10"

    load_balancer_sku = "standard"
    load_balancer_profile {
      outbound_ip_address_ids = [azurerm_public_ip.ip.id]
    }
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
output "consul_root_token" {
  value     = hcp_consul_cluster_root_token.token.secret_id
  sensitive = true
}

output "consul_url" {
  value = hcp_consul_cluster.main.consul_public_endpoint_url
}

output "hashicups_url" {
  value = azurerm_public_ip.ip.fqdn
}

output "next_steps" {
  value = "Hashicups Application will be ready in ~2 minutes. Use 'terraform output consul_root_token' to retrieve the root token."
}
