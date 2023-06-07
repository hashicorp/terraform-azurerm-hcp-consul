locals {
  hvn_region      = "{{ .HVNRegion }}"
  hvn_id          = "{{ .ClusterID }}-hvn"
  cluster_id      = "{{ .ClusterID }}"
  subscription_id = "{{ .SubscriptionID }}"
  vnet_rg_name    = "{{ .VnetRgName }}"
  vnet_id         = "/subscriptions/{{ .SubscriptionID }}/resourceGroups/{{ .VnetRgName }}/providers/Microsoft.Network/virtualNetworks/{{ .VnetName }}"
  subnet1_id      = "/subscriptions/{{ .SubscriptionID }}/resourceGroups/{{ .VnetRgName }}/providers/Microsoft.Network/virtualNetworks/{{ .VnetName }}/subnets/{{ .Subnet1Name }}"
  subnet2_id      = "/subscriptions/{{ .SubscriptionID }}/resourceGroups/{{ .VnetRgName }}/providers/Microsoft.Network/virtualNetworks/{{ .VnetName }}/subnets/{{ .Subnet2Name }}"
  vnet_subnets = {
    "subnet1" = local.subnet1_id,
    "subnet2" = local.subnet2_id,
  }
}


terraform {
  required_providers {
    azurerm = {
      source                = "hashicorp/azurerm"
      version               = "~> 3.59"
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

# Configure providers to use the credentials from the AKS cluster.
provider "helm" {
  kubernetes {
    client_certificate     = base64decode(azurerm_kubernetes_cluster.k8.kube_config.0.client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.k8.kube_config.0.client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.k8.kube_config.0.cluster_ca_certificate)
    host                   = azurerm_kubernetes_cluster.k8.kube_config.0.host
    password               = azurerm_kubernetes_cluster.k8.kube_config.0.password
    username               = azurerm_kubernetes_cluster.k8.kube_config.0.username
  }
}

provider "kubernetes" {
  client_certificate     = base64decode(azurerm_kubernetes_cluster.k8.kube_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.k8.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.k8.kube_config.0.cluster_ca_certificate)
  host                   = azurerm_kubernetes_cluster.k8.kube_config.0.host
  password               = azurerm_kubernetes_cluster.k8.kube_config.0.password
  username               = azurerm_kubernetes_cluster.k8.kube_config.0.username
}

provider "kubectl" {
  client_certificate     = base64decode(azurerm_kubernetes_cluster.k8.kube_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.k8.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.k8.kube_config.0.cluster_ca_certificate)
  host                   = azurerm_kubernetes_cluster.k8.kube_config.0.host
  load_config_file       = false
  password               = azurerm_kubernetes_cluster.k8.kube_config.0.password
  username               = azurerm_kubernetes_cluster.k8.kube_config.0.username
}

provider "azurerm" {
  subscription_id = local.subscription_id
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

data "azurerm_resource_group" "rg" {
  name = local.vnet_rg_name
}

resource "azurerm_route_table" "rt" {
  name                = "${local.cluster_id}-rt"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
}

resource "azurerm_network_security_group" "nsg" {
  name                = "${local.cluster_id}-nsg"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
}


# Create an HCP HVN.
resource "hcp_hvn" "hvn" {
  cidr_block     = "172.25.32.0/20"
  cloud_provider = "azure"
  hvn_id         = local.hvn_id
  region         = local.hvn_region
}

# Note: Uncomment the below module to setup peering for connecting to a private HCP Consul cluster
# Peer the HVN to the vnet.
# module "hcp_peering" {
#   source  = "hashicorp/hcp-consul/azurerm"
#   version = "~> 0.3.2"
#
#   hvn    = hcp_hvn.hvn
#   prefix = local.cluster_id
#
#   security_group_names = [azurerm_network_security_group.nsg.name]
#   subscription_id      = data.azurerm_subscription.current.subscription_id
#   tenant_id            = data.azurerm_subscription.current.tenant_id
#
#   subnet_ids = [local.subnet1_id,local.subnet2_id]
#   vnet_id    = local.vnet_id
#   vnet_rg    = data.azurerm_resource_group.rg.name
# }

# Create the Consul cluster.
resource "hcp_consul_cluster" "main" {
  cluster_id         = local.cluster_id
  hvn_id             = hcp_hvn.hvn.hvn_id
  public_endpoint    = true
  tier               = "development"
  min_consul_version = "v1.14.0"
}

resource "hcp_consul_cluster_root_token" "token" {
  cluster_id = hcp_consul_cluster.main.id
}

# Create a user assigned identity (required for UserAssigned identity in combination with brining our own subnet/nsg/etc)
resource "azurerm_user_assigned_identity" "identity" {
  name                = "aks-identity"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
}

# Create the AKS cluster.
resource "azurerm_kubernetes_cluster" "k8" {
  name                    = local.cluster_id
  dns_prefix              = local.cluster_id
  location                = data.azurerm_resource_group.rg.location
  private_cluster_enabled = false
  resource_group_name     = data.azurerm_resource_group.rg.name

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
    pod_subnet_id   = local.subnet1_id
    vnet_subnet_id  = local.subnet2_id
  }

  identity {
    type                      = "UserAssigned"
    user_assigned_identity_id = azurerm_user_assigned_identity.identity.id
  }

}

# Create a Kubernetes client that deploys Consul and its secrets.
module "aks_consul_client" {
  source  = "hashicorp/hcp-consul/azurerm//modules/hcp-aks-client"
  version = "~> 0.3.2"

  cluster_id = hcp_consul_cluster.main.cluster_id
  # strip out url scheme from the public url
  consul_hosts       = tolist([substr(hcp_consul_cluster.main.consul_public_endpoint_url, 8, -1)])
  consul_version     = hcp_consul_cluster.main.consul_version
  k8s_api_endpoint   = azurerm_kubernetes_cluster.k8.kube_config.0.host
  boostrap_acl_token = hcp_consul_cluster_root_token.token.secret_id
  datacenter         = hcp_consul_cluster.main.datacenter

  # The AKS node group will fail to create if the clients are
  # created at the same time. This forces the client to wait until
  # the node group is successfully created.
  depends_on = [azurerm_kubernetes_cluster.k8]
}

# Deploy Hashicups.
module "demo_app" {
  source  = "hashicorp/hcp-consul/azurerm//modules/k8s-demo-app"
  version = "~> 0.3.2"

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
  destination_port_range      = "8080"
  source_address_prefix       = "*"
  destination_address_prefix  = module.demo_app.load_balancer_ip
  resource_group_name         = data.azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg.name

  depends_on = [module.demo_app]
}

output "consul_root_token" {
  value     = hcp_consul_cluster_root_token.token.secret_id
  sensitive = true
}

output "consul_url" {
  value = hcp_consul_cluster.main.consul_public_endpoint_url
}

output "hashicups_url" {
  value = "${module.demo_app.hashicups_url}:8080"
}

output "next_steps" {
  value = "Hashicups Application will be ready in ~2 minutes. Use 'terraform output consul_root_token' to retrieve the root token."
}

output "kube_config_raw" {
  value     = azurerm_kubernetes_cluster.k8.kube_config_raw
  sensitive = true
}
