# ========================================================
# 1. CLUSTER MINIKUBE
# ========================================================
resource "minikube_cluster" "custom" {
  cluster_name       = var.cluster_name
  driver             = var.driver
  memory             = var.memory
  container_runtime = var.container_runtime
  cni                = var.cni
  addons             = var.addons
  base_image         = var.base_image
  cpus               = var.cpus
  nodes              = var.nodes
  kubernetes_version = var.kubernetes_version
}

# ========================================================
# 2. BACKEND: DEPLOY E EXPOSIÇÃO DE PORTAS
# ========================================================

# 2.1. Execução do Script de Deploy do Backend
resource "null_resource" "apply_k8s" {
  depends_on = [minikube_cluster.custom]

  triggers = {
    script_hash     = filemd5("${path.module}/scripts/apply-k8s.sh")
    deployment_hash = filemd5("${path.module}/scripts/k8s/back/deployment.yaml")
  }

  provisioner "local-exec" {
    command     = "bash ${path.module}/scripts/apply-k8s.sh"
    interpreter = ["bash", "-c"]
  }
}

# 2.2. Exposição da Porta do Backend (8080:8080)
resource "null_resource" "expose_service" {
  depends_on = [null_resource.apply_k8s]

  triggers = {
    deployment_hash = filemd5("${path.module}/scripts/k8s/back/deployment.yaml")
  }

  # Executado no 'terraform apply': Aguarda os pods e expõe em background
  provisioner "local-exec" {
    command     = <<EOT
      echo "⏳ Aguardando o Deployment do Backend ficar 100% Ready..."
      kubectl rollout status deployment/backend-deployment --timeout=180s
      kubectl wait --for=condition=Ready pod -l app=backend --timeout=180s

      echo "🚀 Backend pronto! Iniciando o port-forward (8080:8080)..."
      nohup kubectl port-forward service/backend-service --address 0.0.0.0 8080:8080 > /dev/null 2>&1 &
    EOT
    interpreter = ["bash", "-c"]
  }

  # Executado no 'terraform destroy': Encerra o processo de background
  provisioner "local-exec" {
    when        = destroy
    command     = "pkill -f 'kubectl port-forward service/backend-service' || true"
    interpreter = ["bash", "-c"]
  }
}

# ========================================================
# 3. FRONTEND: DEPLOY E EXPOSIÇÃO DE PORTAS
# ========================================================

# 3.1. Execução do Script de Deploy do Frontend
resource "null_resource" "apply_k8s_front" {
  depends_on = [
    minikube_cluster.custom,
    null_resource.apply_k8s # Garante que o backend suba antes ou junto
  ]

  triggers = {
    script_hash     = filemd5("${path.module}/scripts/apply-k8s-front.sh")
    deployment_hash = filemd5("${path.module}/scripts/k8s/front/deployment.yaml")
  }

  provisioner "local-exec" {
    command     = "bash ${path.module}/scripts/apply-k8s-front.sh"
    interpreter = ["bash", "-c"]
  }
}

# 3.2. Exposição da Porta do Frontend (3000:80)
resource "null_resource" "expose_frontend_service" {
  depends_on = [null_resource.apply_k8s_front]

  triggers = {
    deployment_hash = filemd5("${path.module}/scripts/k8s/front/deployment.yaml")
  }

  # Executado no 'terraform apply': Aguarda os pods e expõe em background
  provisioner "local-exec" {
    command     = <<EOT
      echo "⏳ Aguardando o Deployment do Frontend ficar 100% Ready..."
      kubectl rollout status deployment/frontend-deployment --timeout=180s
      kubectl wait --for=condition=Ready pod -l app=frontend --timeout=180s

      echo "🌐 Frontend pronto! Iniciando o port-forward (3000:80)..."
      nohup kubectl port-forward service/frontend-service --address 0.0.0.0 3000:80 > /dev/null 2>&1 &
    EOT
    interpreter = ["bash", "-c"]
  }

  # Executado no 'terraform destroy': Encerra o processo de background
  provisioner "local-exec" {
    when        = destroy
    command     = "pkill -f 'kubectl port-forward service/frontend-service' || true"
    interpreter = ["bash", "-c"]
  }
}