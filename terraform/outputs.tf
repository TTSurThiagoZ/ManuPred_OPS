output "cluster_name" {
  description = "Nome do cluster Minikube"
  value       = minikube_cluster.custom.cluster_name
}

output "cluster_host" {
  description = "Endereço do Host / Endpoint da API do Kubernetes"
  value       = minikube_cluster.custom.host
}

output "client_certificate" {
  description = "Certificado de cliente para o cluster"
  value       = minikube_cluster.custom.client_certificate
  sensitive   = true
}

output "client_key" {
  description = "Chave privada de cliente para o cluster"
  value       = minikube_cluster.custom.client_key
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Certificado da CA do cluster"
  value       = minikube_cluster.custom.cluster_ca_certificate
  sensitive   = true
}
