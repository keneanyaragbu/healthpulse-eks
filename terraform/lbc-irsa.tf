# IAM role for the AWS Load Balancer Controller, created via the EKS module's
# IRSA submodule. Because it lives in Terraform, it is bound to THIS cluster's
# OIDC provider and is recreated correctly on every apply/destroy cycle —
# no orphaned roles, no manual eksctl step.

module "lbc_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name                              = "${local.name}-lbc"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

output "lbc_role_arn" {
  description = "IAM role ARN for the AWS Load Balancer Controller service account"
  value       = module.lbc_irsa.iam_role_arn
}
