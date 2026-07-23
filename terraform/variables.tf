variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "project_name" {
  description = "Project name used as a resource name prefix"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, uat, prod)"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS control plane"
  type        = string
}

variable "cluster_public_access_cidrs" {
  description = "CIDRs allowed to reach the public EKS API endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "apps_instance_type" {
  description = "Instance type for the application node group"
  type        = string
}

variable "apps_min_size" {
  description = "Minimum nodes in the application node group"
  type        = number
}

variable "apps_max_size" {
  description = "Maximum nodes in the application node group"
  type        = number
}

variable "apps_desired_size" {
  description = "Desired nodes in the application node group"
  type        = number
}

variable "monitoring_instance_type" {
  description = "Instance type for the dedicated monitoring node group"
  type        = string
}
