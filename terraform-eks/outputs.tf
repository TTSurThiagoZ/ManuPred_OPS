# --------------------------------------------------
# CLUSTER
# --------------------------------------------------
output "cluster_name" {
  description = "Nome do cluster EKS"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint do API Server do EKS"
  value       = module.eks.cluster_endpoint
}

output "cluster_ca_certificate" {
  description = "Certificado da Autoridade Certificadora (CA) do cluster"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "kubeconfig_command" {
  description = "Configura o kubectl local (o apply também gera terraform-eks/.kube/config)"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

# --------------------------------------------------
# APLICAÇÃO (Services criados pelos scripts via kubectl)
# --------------------------------------------------
output "app_urls_command" {
  description = "Mostra os Load Balancers (EXTERNAL-IP) do backend e do frontend"
  value       = "kubectl --kubeconfig .kube/config -n ${var.namespace} get svc"
}

output "frontend_url" {
  description = "URL pública do frontend (API Gateway)"
  value       = local.frontend_public_url
}

output "backend_api_url" {
  description = "URL pública do backend (API Gateway). Use como REACT_APP_API_URL no frontend"
  value       = local.backend_public_url
}

# --------------------------------------------------
# BANCO DE DADOS
# --------------------------------------------------
output "rds_endpoint" {
  description = "Endpoint do RDS MySQL (acessível apenas de dentro da VPC)"
  value       = aws_db_instance.mysql.address
}

output "db_password" {
  description = "Senha do MySQL (ver com: terraform output -raw db_password)"
  value       = random_password.db.result
  sensitive   = true
}
