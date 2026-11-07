#!/usr/bin/env bash

set -e

# 1. Obter o diretório onde o script está localizado
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 2. Nome do cluster Minikube (usando variável de ambiente com valor padrão)
CLUSTER_NAME="${CLUSTER_NAME:-minikube-custom}"

DEPLOYMENT_FILE="$SCRIPT_DIR/k8s/front/deployment.yaml"

echo "=================================================="
echo " 🚀 Iniciando o Deploy do Frontend                 "
echo "=================================================="

# 3. Verificar se o cluster minikube está rodando
echo "Verificando o status do cluster '$CLUSTER_NAME'..."
if ! minikube status -p "$CLUSTER_NAME" >/dev/null 2>&1; then
    echo "⚡ O cluster '$CLUSTER_NAME' está desligado. Iniciando..."
    minikube start -p "$CLUSTER_NAME"
else
    echo "✅ Cluster '$CLUSTER_NAME' está em execução."
fi

# 4. Validar a existência do arquivo do deployment
if [ ! -f "$DEPLOYMENT_FILE" ]; then
    echo "❌ Erro: Arquivo de deployment do frontend não encontrado em: $DEPLOYMENT_FILE"
    exit 1
fi

# 5. Aplicar os manifestos no Kubernetes
echo "📦 Aplicando os manifestos do Frontend no cluster..."
kubectl apply -f "$DEPLOYMENT_FILE"

echo "=================================================="
echo " 🎉 Deploy do Frontend concluído com sucesso!     "
echo "=================================================="