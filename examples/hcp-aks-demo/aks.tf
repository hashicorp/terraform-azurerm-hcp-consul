module "aks" {
  source                           = "Azure/aks/azurerm"
  version                          = "4.14.0"
  resource_group_name              = azurerm_resource_group.rg.name 
  prefix                           = var.cluster_id
  cluster_name                     = var.cluster_id
  agents_size                      = "standard_d2s_v5"
  network_plugin                   = "azure"
  vnet_subnet_id                   = module.network.vnet_subnets[0]
  os_disk_size_gb                  = 50
  private_cluster_enabled          = false
  agents_count                     = 2
  sku_tier                         = "Free"
  agents_max_pods                  = 100
  agents_pool_name                 = "nodepool"
  network_policy                 = "azure"
  net_profile_dns_service_ip     = "10.0.0.10"
  net_profile_docker_bridge_cidr = "170.10.0.1/16"
  net_profile_service_cidr       = "10.0.0.0/24"

  depends_on = [module.network]
}