module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = local.name
  cluster_version = var.cluster_version

  # Public endpoint so you can run kubectl from your laptop.
  # Production restricts this to a VPN CIDR or uses private-only + a bastion.
  cluster_endpoint_public_access       = true
  cluster_endpoint_public_access_cidrs = var.cluster_public_access_cidrs

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Creates the OIDC provider that makes IRSA possible.
  enable_irsa = true

  # Grants the identity running `terraform apply` cluster-admin via an
  # EKS Access Entry. This replaced the old aws-auth ConfigMap in EKS.
  enable_cluster_creator_admin_permissions = true

  # AWS-managed add-ons. EKS installs and upgrades these for you.
  cluster_addons = {
    coredns                = {}
    eks-pod-identity-agent = {}
    kube-proxy             = {}
    vpc-cni                = {}
  }

  eks_managed_node_groups = {

    # ---------------------------------------------------------------
    # NODE GROUP 1: application workloads
    # ---------------------------------------------------------------
    apps = {
      name = "${local.name}-apps"

      instance_types = [var.apps_instance_type]
      capacity_type  = "ON_DEMAND"

      min_size     = var.apps_min_size
      max_size     = var.apps_max_size
      desired_size = var.apps_desired_size

      labels = {
        workload = "apps"
      }

      # No taint — this is the default landing zone for pods.
    }

    # ---------------------------------------------------------------
    # NODE GROUP 2: dedicated monitoring workloads
    # The taint REPELS every pod that does not explicitly tolerate it,
    # so Prometheus and Grafana get this node to themselves.
    # ---------------------------------------------------------------
    monitoring = {
      name = "${local.name}-mon"

      instance_types = [var.monitoring_instance_type]
      capacity_type  = "ON_DEMAND"

      min_size     = 1
      max_size     = 2
      desired_size = 1

      labels = {
        workload = "monitoring"
      }

      taints = {
        dedicated = {
          key    = "dedicated"
          value  = "monitoring"
          effect = "NO_SCHEDULE"
        }
      }
    }
  }
}
