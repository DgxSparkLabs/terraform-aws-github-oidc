locals {
  # Immutable OIDC subject prefix: repo:<owner>@<owner_id>/<repo>@<repo_id>
  # (GitHub Actions immutable subject claim, delimiter "@").
  subject_prefix = "repo:${var.github_owner}@${var.github_owner_id}/${var.github_repo}@${var.github_repo_id}"

  roles = {
    plan = {
      name = coalesce(var.plan_role_name, "${var.github_repo}-plan")
      # Exact mainline-branch subject, plus an optional pull_request subject.
      # NOTE: AWS can only match sub/aud (no base_ref/event_name), so the
      # pull_request value trusts EVERY same-repo PR on any base branch.
      subjects = concat(
        ["${local.subject_prefix}:ref:refs/heads/${var.mainline_branch}"],
        var.plan_trusts_pull_requests ? ["${local.subject_prefix}:pull_request"] : [],
      )
      policy_arns = var.plan_role_policy_arns
    }
    apply = {
      name        = coalesce(var.apply_role_name, "${var.github_repo}-apply")
      subjects    = ["${local.subject_prefix}:environment:${var.apply_environment}"]
      policy_arns = var.apply_role_policy_arns
    }
  }

  # Flatten per-role policy attachments into a single keyed map. Key by index,
  # not by ARN: the ARN is often a computed value (e.g. aws_iam_policy.x.arn
  # created in the same config), and for_each keys must be known at plan time.
  policy_attachments = merge([
    for role_key, role in local.roles : {
      for idx, arn in role.policy_arns :
      "${role_key}|${idx}" => { role_key = role_key, policy_arn = arn }
    }
  ]...)
}

data "aws_iam_policy_document" "assume_role" {
  for_each = local.roles

  statement {
    sid     = "GithubActionsOidc"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.openid_connect_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.github_oidc_issuer}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.github_oidc_issuer}:sub"
      values   = each.value.subjects
    }

    dynamic "condition" {
      for_each = var.additional_trust_conditions
      content {
        test     = condition.value.test
        variable = condition.value.variable
        values   = condition.value.values
      }
    }
  }
}

resource "aws_iam_role" "this" {
  for_each = local.roles

  name                 = each.value.name
  path                 = var.role_path
  permissions_boundary = var.role_permissions_boundary
  max_session_duration = var.role_max_session_duration
  assume_role_policy   = data.aws_iam_policy_document.assume_role[each.key].json
  tags                 = var.tags

  lifecycle {
    precondition {
      condition     = length(each.value.name) <= 64
      error_message = "IAM role name exceeds the 64-character limit. Set plan_role_name / apply_role_name to a shorter value."
    }
  }
}

resource "aws_iam_role_policy_attachment" "this" {
  for_each = local.policy_attachments

  role       = aws_iam_role.this[each.value.role_key].name
  policy_arn = each.value.policy_arn
}
