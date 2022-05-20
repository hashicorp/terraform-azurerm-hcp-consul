
output "consul_root_token" {
  value     = hcp_consul_cluster_root_token.token.secret_id
  sensitive = true
}

output "consul_url" {
  value = hcp_consul_cluster.main.consul_public_endpoint_url
}

output "nomad_url" {
  value = "http://${module.vm_client.public_ip}:8081"
}

output "hashicups_url" {
  value = "http://${module.vm_client.public_ip}"
}

output "private_key_openssh" {
  value     = tls_private_key.ssh.private_key_openssh
  sensitive = true
}

output "vm_client_public_ip" {
  value = module.vm_client.public_ip
}

output "next_steps" {
  value = <<EOT
Hashicups Application will be ready in ~5 minutes.

Use 'terraform output consul_root_token' to retrieve the root token.

To SSH into your VM:

  pem=~/.ssh/hashicups.pem
  tf output -raw private_key_openssh > $pem
  chmod 400 $pem
  ssh -i $pem adminuser@$(tf output -raw vm_client_public_ip)
EOT
}
