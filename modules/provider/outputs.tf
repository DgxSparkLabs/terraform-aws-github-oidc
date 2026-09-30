output "openid_connect_provider" {
  description = "AWS OpenID Connect identity provider for GitHub Actions."
  value       = aws_iam_openid_connect_provider.github_actions
}

output "arn" {
  description = "ARN of the OIDC provider, to pass as openid_connect_provider_arn to the root module."
  value       = aws_iam_openid_connect_provider.github_actions.arn
}
