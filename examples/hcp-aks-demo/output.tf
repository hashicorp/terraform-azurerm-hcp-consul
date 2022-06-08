
output "consul_root_token" {
  value     = hcp_consul_cluster_root_token.token.secret_id
  sensitive = true
}

output "consul_url" {
  value = hcp_consul_cluster.main.consul_public_endpoint_url
}

# TODO: Implement Hashicups and add a node to the "next_steps" output below 
#output "hashicups_url" {
#  value = "http://${module.vm_client.public_ip}"
#}

output "next_steps" {
  value = <<EOT
Use 'terraform output consul_root_token' to retrieve the root token.
EOT
}
