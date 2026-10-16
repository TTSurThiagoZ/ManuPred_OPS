terraform {
  required_version = ">= 1.4.0"
  required_providers {
    minikube = {
      source  = "scott-the-programmer/minikube"
      version = ">= 0.3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.4.0"
    }
  }
}

provider "minikube" {  # Utiliza as configurações locais do Docker/Minikube na máquina host
  kubernetes_version = "v1.37.0"
}