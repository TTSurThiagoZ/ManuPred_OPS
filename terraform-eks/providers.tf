terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }

  # Opcional: estado remoto no S3 (recomendado se mais de uma pessoa for rodar).
  # Crie o bucket antes e descomente:
  # backend "s3" {
  #   bucket       = "kipper-terraform-state"
  #   key          = "eks/terraform.tfstate"
  #   region       = "us-east-1"
  #   use_lockfile = true
  # }
}

# 1. Provider AWS — credenciais vêm do ambiente (AWS_PROFILE, AWS_ACCESS_KEY_ID, etc.)
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.tags
  }
}

# 2. Helm (usado só no metrics-server). As aplicações vão pelos scripts via kubectl.
#    O token é gerado pelo AWS CLI a cada chamada (mesmo mecanismo do kubeconfig
#    dos scripts). Não usar data "aws_eks_cluster_auth": o token dele vale 15 min
#    e expira durante o apply, enquanto o EKS/RDS são criados.
provider "helm" {
  kubernetes = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.aws_region]
    }
  }
}

locals {
  tags = {
    Project     = "Kipper"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
