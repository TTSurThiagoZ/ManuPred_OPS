#!/usr/bin/env bash
# --------------------------------------------------
# DEPLOY DO FRONTEND
# Variáveis extras: FRONTEND_IMAGE, FRONTEND_NODE_PORT, FRONTEND_PUBLIC_URL
# --------------------------------------------------
source "$(dirname "$0")/common.sh"

: "${FRONTEND_IMAGE:?FRONTEND_IMAGE não definido}"
: "${FRONTEND_NODE_PORT:=30880}"
: "${FRONTEND_PUBLIC_URL:?FRONTEND_PUBLIC_URL não definido}"
export FRONTEND_IMAGE FRONTEND_NODE_PORT

setup_kubeconfig

echo "🚀 Aplicando manifestos do Frontend..."
envsubst '${FRONTEND_IMAGE} ${FRONTEND_NODE_PORT}' < scripts/k8s/frontend/deployment.yaml | k apply -f -

echo "⏳ Aguardando o Frontend ficar 100% Ready..."
k rollout status deployment/frontend-deployment --timeout=300s

# Entrada pública: API Gateway -> VPC Link -> NLB interno -> NodePort
echo "✅ Frontend disponível em: ${FRONTEND_PUBLIC_URL}"
