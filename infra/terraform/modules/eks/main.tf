module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id                   = var.vpc_id
  subnet_ids               = var.subnet_ids
  control_plane_subnet_ids = var.subnet_ids

  # Grant cluster admin permissions to the AWS IAM user/role that creates the cluster
  enable_cluster_creator_admin_permissions = true

  # Enable IAM Roles for Service Accounts (IRSA)
  # This allows Kubernetes Pods to authenticate with AWS APIs using IAM roles.
  enable_irsa = true

  # Define the worker nodes (EC2 instances) that will run our pods
  eks_managed_node_groups = {
    core_node_group = {
      name           = "${var.cluster_name}-core-ng"
      min_size       = 1
      max_size       = 5
      desired_size   = 2
      instance_types = ["m6i.large"] # Compute-optimized instances
      capacity_type  = "ON_DEMAND"
    }
  }
}

# =========================================================
# IRSA (IAM Roles for Service Accounts) Configurations
# =========================================================

# Creates an IAM role specifically for the AWS Load Balancer Controller
module "load_balancer_controller_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.30"

  role_name = "${var.cluster_name}-aws-lbc-role"

  # This flag automatically attaches the complex IAM policies required to manage ALBs
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    ex = {
      provider_arn = module.eks.oidc_provider_arn
      # Bind this IAM role to a specific Kubernetes Service Account
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

# Creates an IAM role specifically for the External Secrets Operator
module "external_secrets_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.30"

  role_name = "${var.cluster_name}-external-secrets-role"

  # This flag automatically attaches the policies required to read from Secrets Manager
  attach_external_secrets_policy = true

  # Restrict access to only secrets starting with 'omnipayx-' for better security
  external_secrets_secrets_manager_arns              = ["arn:aws:secretsmanager:*:*:secret:omnipayx-*"]
  external_secrets_secrets_manager_create_permission = false

  oidc_providers = {
    ex = {
      provider_arn = module.eks.oidc_provider_arn
      # Bind this IAM role to the External Secrets Service Account
      namespace_service_accounts = ["external-secrets:external-secrets"]
    }
  }
}
