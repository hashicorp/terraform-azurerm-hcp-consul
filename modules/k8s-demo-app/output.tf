output "hashicups_url" {
  value = "http://${data.kubernetes_service.ingress.status[0].load_balancer[0].ingress[0].ip}"
}

output "load_balancer_ip" {
  value = data.kubernetes_service.ingress.status[0].load_balancer[0].ingress[0].ip
}
