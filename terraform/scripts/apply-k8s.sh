#!/usr/bin/env bash

set -e

# Obter o diretorio onde o script esta localizado
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Nome do cluster e da Secret
CLUSTER_NAME="${CLUSTER_NAME:-minikube-custom}"
SECRET_NAME="${SECRET_NAME:-firebase-secret}"

FIREBASE_JSON_PATH="$SCRIPT_DIR/serviceAccountKey.json"
DEPLOYMENT_FILE="$SCRIPT_DIR/k8s/back/deployment.yaml"

echo "=================================================="
echo " 🚀 Iniciando o Deploy do Backend                 "
echo "=================================================="

# 0. Verificar se o cluster minikube esta rodando
echo "Verificando o status do cluster '$CLUSTER_NAME'..."
if ! minikube status -p "$CLUSTER_NAME" >/dev/null 2>&1; then
    echo "⚡ O cluster '$CLUSTER_NAME' está desligado. Iniciando..."
    minikube start -p "$CLUSTER_NAME"
else
    echo "✅ Cluster '$CLUSTER_NAME' está em execução."
fi

echo "Obtendo o IP do host para resolucao de DNS..."

# Extrai APENAS o formato de IP (IPv4) limpo, ignorando avisos de SSH do minikube
RAW_IP=$(minikube -p "$CLUSTER_NAME" ssh "getent hosts host.minikube.internal" 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -n 1 | tr -d '\r\n' || true)

echo $RAW_IP

if [ -n "$RAW_IP" ]; then
    HOST_IP="$RAW_IP"
else
    HOST_IP="172.17.0.1"
fi

export HOST_IP
echo "IP do Host detectado: $HOST_IP"

# 1. Validar a existencia das credenciais
if [ ! -f "$FIREBASE_JSON_PATH" ]; then
    echo "❌ Erro: Arquivo de credenciais nao encontrado em: $FIREBASE_JSON_PATH"
    exit 1
fi

# 2. Validar a existencia do deployment
if [ ! -f "$DEPLOYMENT_FILE" ]; then
    echo "❌ Erro: Arquivo de deployment nao encontrado em: $DEPLOYMENT_FILE"
    exit 1
fi

# 3. Criar/Atualizar a Secret a partir do arquivo JSON
echo "🔐 Criando/Atualizando a Secret '$SECRET_NAME' no Kubernetes..."
kubectl create secret generic firebase-secret \
    --from-file="$FIREBASE_JSON_PATH" \
    --dry-run=client -o yaml | kubectl apply -f -

# 4. Aplicar o Deployment substituindo dinamicamente a variavel ${HOST_IP}
echo "📦 Aplicando o Deployment com HOST_IP=$HOST_IP..."
sed "s/\${HOST_IP}/$HOST_IP/g" "$DEPLOYMENT_FILE" | kubectl apply -f -

echo "=================================================="
echo " 🎉 Deploy concluido com sucesso!                  "
echo "=================================================="