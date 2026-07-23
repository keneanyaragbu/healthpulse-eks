#!/bin/bash
# Post-Terraform cluster bootstrap. Idempotent — safe to re-run.
# Usage: ./scripts/bootstrap.sh [cluster-name] [region]

set -euo pipefail

CLUSTER_NAME="${1:-healthpulse-dev}"
REGION="${2:-us-east-1}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> Connecting kubectl to ${CLUSTER_NAME}"
aws eks update-kubeconfig --region "${REGION}" --name "${CLUSTER_NAME}"
kubectl get nodes -L workload

echo "==> Installing metrics-server (required for HPA and kubectl top)"
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl rollout status deployment metrics-server -n kube-system --timeout=120s

echo "==> Installing kube-prometheus-stack on the dedicated monitoring node"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update >/dev/null
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install monitoring \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  -f "${REPO_ROOT}/k8s/monitoring-values.yaml" \
  --wait --timeout 10m

echo "==> Installing ArgoCD"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd --server-side -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl rollout status deployment argocd-server -n argocd --timeout=300s

echo ""
echo "==================== READY ===================="
kubectl get pods -n monitoring -o wide
echo ""
echo "ArgoCD admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "(secret not created yet)"
echo ""
echo ""
echo "Grafana:  kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80"
echo "          http://localhost:3000  admin / healthpulse123"
echo "ArgoCD:   kubectl port-forward -n argocd svc/argocd-server 8080:443"
echo "          https://localhost:8080  admin / (password above)"
echo "==============================================="
