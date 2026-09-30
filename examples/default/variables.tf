variable "aws_region" {
  description = "AWS region."
  type        = string
  default     = "eu-west-1"
}

variable "github_owner" {
  description = "GitHub owner login (e.g. \"my-org\")."
  type        = string
  default     = "my-org"
}

variable "github_owner_id" {
  description = "Immutable numeric GitHub owner (account) ID."
  type        = string
  default     = "111111"
}

variable "github_repo" {
  description = "Repository name (e.g. \"my-repo\")."
  type        = string
  default     = "my-repo"
}

variable "github_repo_id" {
  description = "Immutable numeric GitHub repository ID."
  type        = string
  default     = "222222"
}

variable "mainline_branch" {
  description = "Branch the plan role trusts."
  type        = string
  default     = "main"
}

variable "apply_environment" {
  description = "Protected GitHub environment the apply role trusts."
  type        = string
  default     = "production"
}

variable "plan_role_policy_arns" {
  description = "IAM policy ARNs attached to the plan role."
  type        = list(string)
  default     = []
}

variable "apply_role_policy_arns" {
  description = "IAM policy ARNs attached to the apply role."
  type        = list(string)
  default     = []
}
