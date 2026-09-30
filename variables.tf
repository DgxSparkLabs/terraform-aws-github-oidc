variable "openid_connect_provider_arn" {
  description = "ARN of the GitHub Actions OIDC provider. Create it once per AWS account with the ./modules/provider submodule (or reference an existing one) and pass its ARN here."
  type        = string
}

variable "github_owner" {
  description = "GitHub organization or user login that owns the repository (e.g. \"my-org\"), without any slashes or wildcards."
  type        = string
  validation {
    condition     = can(regex("^[A-Za-z0-9-]+$", var.github_owner))
    error_message = "github_owner must be a bare owner login (letters, digits, hyphens; no slash or wildcard)."
  }
}

variable "github_owner_id" {
  description = "Immutable numeric account ID of the GitHub owner. Part of the immutable OIDC subject claim (repos created/renamed/transferred on or after 2026-07-15, or opted in)."
  type        = string
  validation {
    condition     = can(regex("^[0-9]+$", var.github_owner_id))
    error_message = "github_owner_id must be the numeric GitHub owner (account) ID."
  }
}

variable "github_repo" {
  description = "Repository name only, without the owner prefix (e.g. \"my-repo\")."
  type        = string
  validation {
    condition     = can(regex("^[A-Za-z0-9._-]+$", var.github_repo))
    error_message = "github_repo must be the bare repository name (no owner prefix or wildcard)."
  }
}

variable "github_repo_id" {
  description = "Immutable numeric repository ID. Part of the immutable OIDC subject claim."
  type        = string
  validation {
    condition     = can(regex("^[0-9]+$", var.github_repo_id))
    error_message = "github_repo_id must be the numeric GitHub repository ID."
  }
}

variable "mainline_branch" {
  description = "Branch the plan role is allowed to assume from. Matched exactly on the OIDC subject (refs/heads/<mainline_branch>)."
  type        = string
  default     = "main"
}

variable "plan_trusts_pull_requests" {
  description = "(Optional) Also allow the plan role to be assumed from pull_request workflow runs, so PRs can compute a plan. Because AWS can only match sub/aud (not base_ref/event_name), this trusts EVERY same-repo pull request on any base branch, so keep the plan role strictly read-only. The module does not distinguish forks: a fork PR's token carries the base repo's :pull_request subject and would match. GitHub withholds id-token:write from fork PRs by default (an org/repo admin can enable it, after which forks can assume this role). Only takes effect for plan jobs that set no environment:. Default false."
  type        = bool
  default     = false
}

variable "apply_environment" {
  description = "GitHub Actions environment the apply role is allowed to assume from. Matched exactly on the OIDC subject. Protect this environment with required reviewers so applies gate on human approval."
  type        = string
}

variable "plan_role_policy_arns" {
  description = "IAM policy ARNs to attach to the plan role (typically read-only access needed to compute a plan). This module attaches policies but owns no permissions of its own."
  type        = list(string)
  default     = []
}

variable "apply_role_policy_arns" {
  description = "IAM policy ARNs to attach to the apply role (the write access needed to apply). This module attaches policies but owns no permissions of its own."
  type        = list(string)
  default     = []
}

variable "plan_role_name" {
  description = "(Optional) Name of the plan role. Defaults to \"<github_repo>-plan\"."
  type        = string
  default     = null
}

variable "apply_role_name" {
  description = "(Optional) Name of the apply role. Defaults to \"<github_repo>-apply\"."
  type        = string
  default     = null
}

variable "role_path" {
  description = "Path for both created roles."
  type        = string
  default     = "/github-actions/"
}

variable "role_permissions_boundary" {
  description = "(Optional) Permissions boundary ARN applied to both roles."
  type        = string
  default     = null
}

variable "role_max_session_duration" {
  description = "(Optional) Maximum session duration (in seconds) applied to both roles."
  type        = number
  default     = null
}

variable "additional_trust_conditions" {
  description = "(Optional) Extra IAM condition blocks added to BOTH roles' trust policies to TIGHTEN trust by matching an additional claim. NOTE: aws_iam_policy_document merges blocks that share the same operator+variable and ORs their values, so a StringEquals block on the module's own sub/aud keys would WIDEN the match; those are rejected by the validation below. A different operator (e.g. StringNotEquals on :sub) is a separate condition that ANDs, so it tightens and is allowed. Each entry needs test, variable and values."
  type = list(object({
    test     = string
    variable = string
    values   = list(string)
  }))
  default = []
  validation {
    condition = alltrue([
      for c in var.additional_trust_conditions :
      !(c.test == "StringEquals" && (endswith(c.variable, ":sub") || endswith(c.variable, ":aud")))
    ])
    error_message = "additional_trust_conditions must not use StringEquals on the ':sub' or ':aud' claim; those are set by the module and extra values would merge-OR and widen the match. Use a different operator or claim to tighten trust."
  }
}

variable "github_oidc_issuer" {
  description = "OIDC issuer host for GitHub Actions, used as the claim prefix."
  type        = string
  default     = "token.actions.githubusercontent.com"
}

variable "tags" {
  description = "Tags applied to both roles."
  type        = map(string)
  default     = {}
}
