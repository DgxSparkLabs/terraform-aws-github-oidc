output "plan_role" {
  description = "The plan role. Trusts the OIDC token from pushes to the mainline branch."
  value       = aws_iam_role.this["plan"]
}

output "apply_role" {
  description = "The apply role. Trusts the OIDC token from the protected GitHub environment."
  value       = aws_iam_role.this["apply"]
}

output "plan_role_arn" {
  description = "ARN of the plan role, for aws-actions/configure-aws-credentials role-to-assume."
  value       = aws_iam_role.this["plan"].arn
}

output "apply_role_arn" {
  description = "ARN of the apply role, for aws-actions/configure-aws-credentials role-to-assume."
  value       = aws_iam_role.this["apply"].arn
}

output "subjects" {
  description = "The exact OIDC subjects each role trusts."
  value       = { for k, r in local.roles : k => r.subjects }
}
