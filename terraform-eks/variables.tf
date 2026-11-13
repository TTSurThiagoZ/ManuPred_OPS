# --------------------------------------------------
# GERAL
# --------------------------------------------------
variable "aws_region" {
  type        = string
  description = "Região AWS onde a infraestrutura será criada"
  default     = "us-east-1"
}

variable "environment" {
  type        = string
  description = "Nome do ambiente (usado em tags)"
  default     = "tcc"
}

# --------------------------------------------------
# REDE (VPC)
# --------------------------------------------------
variable "vpc_cidr" {
  type        = string
  description = "Bloco CIDR da VPC"
  default     = "10.0.0.0/16"
}

variable "az_count" {
  type        = number
  description = "Quantidade de zonas de disponibilidade (EKS e RDS exigem no mínimo 2)"
  default     = 2
}

# --------------------------------------------------
# CLUSTER EKS (equivalente ao minikube_cluster)
# --------------------------------------------------
variable "cluster_name" {
  type        = string
  description = "Nome do cluster EKS"
  default     = "kipper-eks"
}

variable "kubernetes_version" {
  type        = string
  description = "Versão do Kubernetes no EKS (formato major.minor, ex: 1.34)"
  default     = "1.34"
}

variable "node_instance_types" {
  type        = list(string)
  description = "Tipos de instância EC2 dos nós (equivale a cpus/memory do Minikube)"
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  type        = number
  description = "Quantidade desejada de nós (equivale a 'nodes' do Minikube)"
  default     = 2
}

variable "node_min_size" {
  type        = number
  description = "Quantidade mínima de nós"
  default     = 1
}

variable "node_max_size" {
  type        = number
  description = "Quantidade máxima de nós"
  default     = 3
}

# --------------------------------------------------
# BANCO DE DADOS (RDS MySQL — substitui host.minikube.internal:3310)
# --------------------------------------------------
variable "db_instance_class" {
  type        = string
  description = "Classe da instância RDS"
  default     = "db.t4g.micro"
}

variable "db_engine_version" {
  type        = string
  description = "Versão do MySQL no RDS"
  default     = "8.4"
}

variable "db_allocated_storage" {
  type        = number
  description = "Armazenamento do RDS em GB"
  default     = 20
}

variable "db_name" {
  type        = string
  description = "Nome do schema (o mesmo usado na URL JDBC do backend)"
  default     = "kipper"
}

variable "db_username" {
  type        = string
  description = "Usuário master do MySQL"
  default     = "kipperuser"
}

# --------------------------------------------------
# SCRIPTS DE DEPLOY
# --------------------------------------------------
variable "bash_path" {
  type        = string
  description = "Interpretador bash dos scripts (Windows: Git Bash; Linux/Mac: \"bash\")"
  default     = "C:/Program Files/Git/bin/bash.exe"
}

# --------------------------------------------------
# APLICAÇÃO
# --------------------------------------------------
variable "namespace" {
  type        = string
  description = "Namespace Kubernetes das aplicações"
  default     = "kipper"
}

variable "backend_image" {
  type        = string
  description = "Imagem do backend"
  default     = "thiagofiec/manupred_be:latest"
}

variable "frontend_image" {
  type        = string
  description = "Imagem do frontend (precisa ser buildada com REACT_APP_API_URL apontando para o backend na AWS)"
  default     = "thiagofiec/kipperfe:latest"
}

variable "api_gateway_id" {
  type        = string
  description = "ID do HTTP API do API Gateway (já existente) que fica na frente do backend"
  default     = "o3l1ibqnmb"
}

variable "api_gateway_kipper_route_id" {
  type        = string
  description = "ID da rota \"ANY /kipper\" já criada no API Gateway (importada pelo Terraform). Vazio = o Terraform cria a rota"
  default     = ""
}

variable "frontend_api_gateway_id" {
  type        = string
  description = "ID do HTTP API do API Gateway (já existente) que fica na frente do frontend"
  default     = "l7qnejkr6i"
}

variable "frontend_api_gateway_kipper_route_id" {
  type        = string
  description = "ID da rota \"ANY /kipper\" já criada no API Gateway do frontend (importada pelo Terraform). Vazio = o Terraform cria a rota"
  default     = ""
}

variable "frontend_node_port" {
  type        = number
  description = "NodePort fixo do frontend-service (faixa 30000-32767)"
  default     = 30880
}

variable "backend_node_port" {
  type        = number
  description = "NodePort fixo do backend-service (o NLB interno do API Gateway aponta para ele; faixa 30000-32767)"
  default     = 30808
}

variable "firebase_credentials_file" {
  type        = string
  description = "Caminho do serviceAccountKey.json do Firebase (relativo a esta pasta)"
  default     = "serviceAccountKey.json"
}

variable "frontend_oauth2_redirect_uri" {
  type        = string
  description = "URL de redirect do OAuth2 após login. Vazio = <URL do frontend no API Gateway>/oauth2/redirect"
  default     = ""
}

variable "google_client_id" {
  type        = string
  description = "Client ID do OAuth2 Google (opcional)"
  default     = ""
  sensitive   = true
}

variable "google_client_secret" {
  type        = string
  description = "Client Secret do OAuth2 Google (opcional)"
  default     = ""
  sensitive   = true
}

variable "jwt_secret" {
  type        = string
  description = "Segredo JWT do backend (opcional; vazio = usa o default da aplicação)"
  default     = ""
  sensitive   = true
}
