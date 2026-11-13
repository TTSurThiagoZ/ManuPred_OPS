# --------------------------------------------------
# REDE: VPC com subnets públicas (Load Balancers) e privadas (nós EKS + RDS)
# --------------------------------------------------
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr
  azs  = local.azs

  # /20 para cada subnet: 10.0.0.0/20, 10.0.16.0/20 (privadas) ...
  private_subnets = [for i, _ in local.azs : cidrsubnet(var.vpc_cidr, 4, i)]
  # ... e 10.0.48.0/24, 10.0.49.0/24 (públicas)
  public_subnets = [for i, _ in local.azs : cidrsubnet(var.vpc_cidr, 8, i + 48)]

  # Um único NAT Gateway para economizar (suficiente para o TCC)
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  # Tags que o EKS usa para descobrir onde criar Load Balancers
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
}
