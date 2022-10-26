output "consul_root_token" {
  value     = hcp_consul_cluster_root_token.token.secret_id
  sensitive = true
}

output "consul_url" {
  value = data.hcp_consul_cluster.main.consul_public_endpoint_url
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
