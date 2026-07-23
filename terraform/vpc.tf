data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name = "${var.project_name}-${var.environment}"
  azs  = slice(data.aws_availability_zones.available.names, 0, 2)
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${local.name}-vpc"
  cidr = var.vpc_cidr

  azs = local.azs

  # Private subnets host the worker nodes (no public IPs — enterprise standard)
  private_subnets = [for i, az in local.azs : cidrsubnet(var.vpc_cidr, 4, i)]

  # Public subnets host the internet-facing load balancers and the NAT gateway
  public_subnets = [for i, az in local.azs : cidrsubnet(var.vpc_cidr, 4, i + 8)]

  enable_nat_gateway = true
  single_nat_gateway = true # Cost saving. Production uses one NAT per AZ.

  enable_dns_hostnames = true
  enable_dns_support   = true

  # These tags are REQUIRED. The AWS Load Balancer Controller reads them to
  # discover which subnets it may place load balancers in. Without them,
  # ingress creation silently fails.
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
    # Required by the Cluster Autoscaler to find scalable node groups
    "karpenter.sh/discovery" = local.name
  }
}
