# --------------------------------------------------
# 1. Cluster EKS (equivalente ao minikube_cluster do projeto anterior)
# --------------------------------------------------
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = var.cluster_name
  kubernetes_version = var.kubernetes_version

  # Endpoint público para o Terraform/kubectl da sua máquina alcançarem o cluster
  endpoint_public_access = true

  # Quem roda o 'terraform apply' vira admin do cluster
  enable_cluster_creator_admin_permissions = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Addons gerenciados pela AWS (vpc-cni substitui o CNI flannel do Minikube)
  addons = {
    coredns = {}
    eks-pod-identity-agent = {
      before_compute = true
    }
    kube-proxy = {}
    vpc-cni = {
      before_compute = true
    }
  }

  # Nós de trabalho (equivale a cpus/memory/nodes do Minikube)
  eks_managed_node_groups = {
    default = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = var.node_instance_types

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size
    }
  }
}

# --------------------------------------------------
# 2. metrics-server (era addon do Minikube; necessário para o HPA)
# --------------------------------------------------
resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"
  version    = "3.14.0"

  depends_on = [module.eks]
}
