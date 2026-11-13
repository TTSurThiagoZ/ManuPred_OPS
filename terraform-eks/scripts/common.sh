#!/usr/bin/env bash
# --------------------------------------------------
# FUNÇÕES COMPARTILHADAS PELOS SCRIPTS DE DEPLOY
# Variáveis esperadas (passadas pelo Terraform):
#   CLUSTER_NAME, AWS_REGION, NAMESPACE, KUBECONFIG
# --------------------------------------------------
set -euo pipefail

: "${CLUSTER_NAME:?CLUSTER_NAME não definido}"
: "${AWS_REGION:?AWS_REGION não definido}"
: "${NAMESPACE:=kipper}"
export KUBECONFIG="${KUBECONFIG:-.kube/config}"

# Substitui o 'minikube -p <cluster> kubectl --' do projeto anterior
k() {
  kubectl -n "${NAMESPACE}" "$@"
}

# Gera/atualiza o kubeconfig do EKS (requer AWS CLI)
setup_kubeconfig() {
  echo "🔑 Gerando kubeconfig do cluster ${CLUSTER_NAME} (${AWS_REGION})..."
  mkdir -p "$(dirname "${KUBECONFIG}")"
  aws eks update-kubeconfig \
    --region "${AWS_REGION}" \
    --name "${CLUSTER_NAME}" \
    --kubeconfig "${KUBECONFIG}" > /dev/null
}

# Aguarda o Service LoadBalancer receber o DNS da AWS e imprime o hostname
wait_lb_hostname() {
  local svc="$1" host=""
  echo "⏳ Aguardando o Load Balancer de ${svc}..." >&2
  for _ in $(seq 1 60); do
    host=$(k get service "${svc}" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)
    if [ -n "${host}" ]; then
      echo "${host}"
      return 0
    fi
    sleep 5
  done
  echo "❌ Timeout aguardando o Load Balancer de ${svc}" >&2
  return 1
}
