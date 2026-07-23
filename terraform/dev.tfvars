aws_region   = "us-east-1"
project_name = "healthpulse"
environment  = "dev"

vpc_cidr        = "10.50.0.0/16"
cluster_version = "1.33"

apps_instance_type = "t3.medium"
apps_min_size      = 2
apps_max_size      = 4
apps_desired_size  = 2

monitoring_instance_type = "t3.medium"
