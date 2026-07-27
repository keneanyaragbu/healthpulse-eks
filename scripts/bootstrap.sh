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

echo "==> Applying Grafana ingress"
kubectl apply -f "${REPO_ROOT}/k8s/grafana-ingress.yaml"

echo "==> Installing ArgoCD"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd --server-side -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl rollout status deployment argocd-server -n argocd --timeout=300s
kubectl apply -f "${REPO_ROOT}/argocd/healthpulse-dev.yaml"


echo "==> Installing AWS Load Balancer Controller (IRSA role from Terraform)"
LBC_ROLE_ARN=$(cd "${REPO_ROOT}/terraform" && terraform output -raw lbc_role_arn)
VPC_ID=$(cd "${REPO_ROOT}/terraform" && terraform output -raw vpc_id)

kubectl create serviceaccount aws-load-balancer-controller -n kube-system \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl annotate serviceaccount aws-load-balancer-controller -n kube-system \
  eks.amazonaws.com/role-arn="${LBC_ROLE_ARN}" --overwrite

helm repo add eks https://aws.github.io/eks-charts >/dev/null 2>&1 || true
helm repo update >/dev/null
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --namespace kube-system \
  --set clusterName="${CLUSTER_NAME}" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region="${REGION}" \
  --set vpcId="${VPC_ID}" \
  --wait --timeout 5m

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
