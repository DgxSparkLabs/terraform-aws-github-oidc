output "oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC provider."
  value       = module.oidc_provider.arn
}

output "plan_role_arn" {
  description = "ARN of the plan role."
  value       = module.github_oidc.plan_role_arn
}

output "apply_role_arn" {
  description = "ARN of the apply role."
  value       = module.github_oidc.apply_role_arn
}

output "subjects" {
  description = "The exact OIDC subject each role trusts."
  value       = module.github_oidc.subjects
}
