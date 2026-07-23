# HealthPulse EKS Platform

Managed Kubernetes platform on AWS EKS with a dedicated, isolated
monitoring node group.

---

## Architecture

```
VPC (10.50.0.0/16) across 2 AZs
  ├── Public subnets   → NAT gateway + internet-facing load balancers
  └── Private subnets  → ALL worker nodes (no public IPs)

EKS control plane (managed by AWS — you never SSH into it)
  │
  ├── Node group "apps"       t3.medium ×2   no taint    → HealthPulse pods
  └── Node group "monitoring" t3.medium ×1   TAINTED     → Prometheus, Grafana
```

The monitoring node group carries the taint `dedicated=monitoring:NoSchedule`.
That taint repels every pod that does not explicitly tolerate it, which is
how the observability stack gets a node to itself and can never starve the
application workloads.

---

## Deploy

```bash
cd terraform

terraform init

terraform apply -var-file=dev.tfvars
```

Takes roughly 15 minutes. EKS control plane creation alone is ~10 minutes.

Then point kubectl at the cluster:

```bash
aws eks update-kubeconfig --region us-east-1 --name healthpulse-dev
kubectl get nodes -L workload
```

You should see three nodes with a `WORKLOAD` column showing `apps`, `apps`,
and `monitoring`.

---

## Verify the taint is real

```bash
# Show the taint on the monitoring node
kubectl get nodes -l workload=monitoring -o jsonpath='{.items[*].spec.taints}'

# Try to schedule an ordinary pod onto it — it will be rejected
kubectl run taint-test --image=busybox --restart=Never \
  --overrides='{"spec":{"nodeSelector":{"workload":"monitoring"}}}' \
  -- sleep 300

kubectl get pod taint-test          # Pending
kubectl describe pod taint-test | grep -A5 Events   # "untolerated taint"
kubectl delete pod taint-test
```

That Pending pod is the proof: the taint works.

---

## Install the monitoring stack on the dedicated node

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

kubectl create namespace monitoring

helm upgrade --install monitoring \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  -f ../k8s/monitoring-values.yaml
```

Confirm every monitoring pod landed on the monitoring node:

```bash
kubectl get pods -n monitoring -o wide
```

---

## Destroy

EKS costs money continuously. Destroy when you finish a session.

```bash
cd terraform
terraform destroy -var-file=dev.tfvars
```

| Component | Approx cost |
|-----------|-------------|
| EKS control plane | $0.10 / hour |
| NAT gateway | $0.045 / hour + data |
| 3 × t3.medium | ~$0.125 / hour total |
| **Total** | **~$0.27 / hour** |

---

## Why this differs from self-managed k3s

| Concern | k3s on EC2 | EKS |
|---------|-----------|-----|
| Control plane | You run it on a node you own | AWS runs it, HA across 3 AZs |
| Control plane outage | Your problem | AWS's problem |
| Resize control plane | Rebuild the cluster | Not applicable |
| Node provisioning | Custom user_data scripts | Managed node groups |
| Node upgrades | Manual | Rolling, orchestrated by AWS |
| IAM integration | Manual | IRSA / Pod Identity, native |
| Ingress | Traefik on a node | AWS Load Balancer Controller → real ALB |
