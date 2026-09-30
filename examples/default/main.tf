# Create the OIDC provider once per AWS account.
module "oidc_provider" {
  source = "../../modules/provider"
}

# Create the plan and apply roles for a single repository.
module "github_oidc" {
  source = "../../"

  openid_connect_provider_arn = module.oidc_provider.arn

  github_owner      = var.github_owner
  github_owner_id   = var.github_owner_id
  github_repo       = var.github_repo
  github_repo_id    = var.github_repo_id
  mainline_branch   = var.mainline_branch
  apply_environment = var.apply_environment

  # Permissions are attached externally; this module owns none.
  plan_role_policy_arns  = var.plan_role_policy_arns
  apply_role_policy_arns = var.apply_role_policy_arns
}
