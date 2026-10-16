variable "cluster_name" {
  type        = string
  description = "Nome do cluster Minikube"
  default     = "minikube-custom"
}

variable "driver" {
  type        = string
  description = "Driver para provisionamento do cluster"
  default     = "docker"
}

variable "memory" {
  type        = string
  description = "Quantidade de memória RAM alocada para o cluster"
  default     = "4000mb"
}

variable "container_runtime" {
  type        = string
  description = "Runtime de containers a ser utilizado"
  default     = "containerd"
}

variable "cni" {
  type        = string
  description = "Plugin CNI de rede"
  default     = "flannel"
}

variable "addons" {
  type        = list(string)
  description = "Lista de addons habilitados no Minikube"
  default = [
    "metrics-server",
    "dashboard",
    "default-storageclass",
    "storage-provisioner"
  ]
}

variable "base_image" {
  type        = string
  description = "Imagem base (kicbase) utilizada pelo Minikube"
  default     = "gcr.io/k8s-minikube/kicbase:v0.0.51"
}

variable "cpus" {
  type        = string
  description = "Quantidade de CPUs alocadas para o cluster"
  default     = "2"
}

variable "nodes" {
  type        = number
  description = "Quantidade de nós do cluster"
  default     = 1
}

variable "kubernetes_version" {
  type        = string
  description = "Versão do Kubernetes a ser instalada"
  default     = "v1.37.0"
}

variable "output_filename" {
  type        = string
  description = "Nome do arquivo onde os outputs do cluster serão gravados"
  default     = "cluster_info.txt"
}