# Provisionamento do Cluster Minikube com as novas configurações
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

# Execução automática do script K8s após a criação do cluster ou quando houver alterações
resource "null_resource" "apply_k8s" {
  depends_on = [minikube_cluster.custom]

  triggers = {
    # Reexecuta o deploy sempre que o script shell for alterado
    script_hash = filemd5("${path.module}/scripts/apply-k8s.sh")

    # Reexecuta o deploy sempre que o manifesto Kubernetes for alterado
    deployment_hash = filemd5("${path.module}/scripts/k8s/back/deployment.yaml")

    # (Opcional) Descomente a linha abaixo para forçar o deploy em TODO 'terraform apply':
    # always_run = timestamp()
  }

  provisioner "local-exec" {
    command     = "bash ${path.module}/scripts/apply-k8s.sh"
    interpreter = ["bash", "-c"]
  }
}

# Exposição do Serviço e Redirecionamento de Porta (Port-Forward)

resource "null_resource" "expose_service" {
  depends_on = [null_resource.apply_k8s]

  triggers = {
    deployment_hash = filemd5("${path.module}/scripts/k8s/back/deployment.yaml")
  }

  # Executado no 'terraform apply'
  provisioner "local-exec" {
    command     = <<EOT
      echo "⏳ Aguardando o Deployment e os Pods ficarem 100% Ready..."
      kubectl rollout status deployment/backend-deployment --timeout=180s
      kubectl wait --for=condition=Ready pod -l app=backend --timeout=180s

      echo "🚀 Pods prontos! Iniciando o port-forward em background..."
      nohup kubectl port-forward service/backend-service --address 0.0.0.0 8080:8080 > /dev/null 2>&1 &
    EOT
    interpreter = ["bash", "-c"]
  }

  # Executado no 'terraform destroy'
  provisioner "local-exec" {
    when        = destroy
    command     = "pkill -f 'kubectl port-forward service/backend-service --address 0.0.0.0 8080:8080' || true"
    interpreter = ["bash", "-c"]
  }
}