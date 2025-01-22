output "cluster_name" {
  value = module.eks.cluster_name
}
output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}
output "oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}
output "aws_load_balancer_controller_role_arn" {
  value = module.load_balancer_controller_irsa_role.iam_role_arn
}
output "external_secrets_role_arn" {
  value = module.external_secrets_irsa_role.iam_role_arn
}
