#!/usr/bin/env bash
# --------------------------------------------------
# Uso: ./scripts/namespace.sh apply|delete
# --------------------------------------------------
source "$(dirname "$0")/common.sh"

ACTION="${1:-apply}"

case "${ACTION}" in
  apply)
    setup_kubeconfig
    echo "📦 Criando namespace ${NAMESPACE}..."
    envsubst '${NAMESPACE}' < scripts/k8s/namespace.yaml | kubectl apply -f -
    ;;

  delete)
    # No destroy o cluster pode já não existir — nesse caso não há o que limpar
    if ! setup_kubeconfig; then
      echo "⚠️  Cluster ${CLUSTER_NAME} não encontrado, nada a remover."
      exit 0
    fi

    # Apagar o namespace remove os Services LoadBalancer e aguarda a AWS
    # excluir os Load Balancers — sem isso o destroy da VPC falha.
    echo "🧹 Removendo namespace ${NAMESPACE} e Load Balancers..."
    kubectl delete namespace "${NAMESPACE}" --ignore-not-found --wait=true --timeout=10m
    ;;

  *)
    echo "Uso: $0 apply|delete" >&2
    exit 1
    ;;
esac

echo "✅ namespace.sh ${ACTION} concluído."
