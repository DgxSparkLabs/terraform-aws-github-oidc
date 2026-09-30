# Terraform module — AWS OIDC plan/apply roles for GitHub Actions

This [Terraform](https://www.terraform.io/) module manages OpenID Connect (OIDC)
integration between [GitHub Actions and AWS](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services).

It is an opinionated fork of
[philips-labs/terraform-aws-github-oidc](https://github.com/philips-labs/terraform-aws-github-oidc)
reshaped for a hardened two-role plan/apply workflow.

## Description

For one repository the module creates **two roles**:

- **plan** — assumable only from the mainline branch
  (`sub` = `repo:<owner>@<owner_id>/<repo>@<repo_id>:ref:refs/heads/<mainline_branch>`).
- **apply** — assumable by any token whose `sub` is
  `repo:<owner>@<owner_id>/<repo>@<repo_id>:environment:<apply_environment>`. The
  module does **not** check the branch or event; the GitHub environment's
  deployment-branch rule and required reviewers are what keep apply off pull
  requests and non-mainline branches.

Hardening choices:

- **Exact subject match** with `StringEquals` (never `StringLike`); no wildcards.
- **Immutable subject** — the numeric owner and repository IDs are baked into the
  subject, so a recycled org/repo name cannot assume the role. See GitHub's
  [immutable subject claims](https://github.blog/changelog/2026-04-23-immutable-subject-claims-for-github-actions-oidc-tokens/).
  This requires the repo to emit the immutable subject: repositories **created,
  renamed, or transferred on/after 2026-07-15**, or existing repositories that
  **opt in** at the repo/org level. Repositories still on the legacy name-only
  `sub` (`repo:<owner>/<repo>:...`) are denied by these roles until they adopt it.
- **Audience pinned** to `sts.amazonaws.com`.
- **No trust widening** — this fork intentionally drops the upstream
  `account_ids` / `custom_principal_arns` / `allow_all` knobs. The roles trust
  only the repository's own OIDC token. `additional_trust_conditions` adds
  further claim checks to tighten trust; it rejects a `StringEquals` block on
  `:sub`/`:aud` (which would merge-OR into the module's own checks and widen
  them), while a different operator such as `StringNotEquals` is allowed.
- **No baked-in permissions** — the module attaches policies you supply via
  `plan_role_policy_arns` / `apply_role_policy_arns` and owns none itself.
- **Environment is the branch gate for `apply`** — the `apply` subject
  (`:environment:<apply_environment>`) has no branch component, so *any* branch
  deploying to that environment can assume the apply role. Protect the
  environment with **required reviewers** and **deployment-branch restrictions**
  (limit it to the mainline branch); the trust policy itself does not scope by
  branch.

The OIDC identity provider is one resource per AWS account. Create it once with
the [`./modules/provider`](modules/provider) submodule and pass its ARN to every
instance of the root module, or reference an existing provider.

## Required GitHub workflow permissions

```yaml
permissions:
  id-token: write
  contents: read
```

## Usage

Create the provider once per account:

```hcl
module "oidc_provider" {
  source = "git::https://github.com/DgxSparkLabs/terraform-aws-github-oidc.git//modules/provider?ref=<tag>"
}
```

Create the plan/apply roles for a repository:

```hcl
module "github_oidc" {
  source = "git::https://github.com/DgxSparkLabs/terraform-aws-github-oidc.git?ref=<tag>"

  openid_connect_provider_arn = module.oidc_provider.arn

  github_owner      = "my-org"
  github_owner_id   = "111111"
  github_repo       = "my-repo"
  github_repo_id    = "222222"
  apply_environment = "production"

  # Permissions attached externally; the module owns none.
  plan_role_policy_arns  = [aws_iam_policy.plan.arn]
  apply_role_policy_arns = [aws_iam_policy.apply.arn]
}
```

## Examples

- Terraform: [`examples/default`](examples/default/README.md) — provider + plan/apply roles for one repository.
- GitHub Actions consumer: [`examples/repositories/plan-apply`](examples/repositories/plan-apply/README.md) — a workflow that assumes the plan role on a push to main and the apply role from a protected environment.

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 6.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_iam_role.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_policy_document.assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_openid_connect_provider_arn"></a> [openid\_connect\_provider\_arn](#input\_openid\_connect\_provider\_arn) | ARN of the GitHub Actions OIDC provider. | `string` | n/a | yes |
| <a name="input_github_owner"></a> [github\_owner](#input\_github\_owner) | GitHub owner login (e.g. "my-org"). | `string` | n/a | yes |
| <a name="input_github_owner_id"></a> [github\_owner\_id](#input\_github\_owner\_id) | Immutable numeric GitHub owner (account) ID. | `string` | n/a | yes |
| <a name="input_github_repo"></a> [github\_repo](#input\_github\_repo) | Repository name (no owner prefix). | `string` | n/a | yes |
| <a name="input_github_repo_id"></a> [github\_repo\_id](#input\_github\_repo\_id) | Immutable numeric GitHub repository ID. | `string` | n/a | yes |
| <a name="input_apply_environment"></a> [apply\_environment](#input\_apply\_environment) | Protected GitHub environment the apply role trusts. | `string` | n/a | yes |
| <a name="input_mainline_branch"></a> [mainline\_branch](#input\_mainline\_branch) | Branch the plan role trusts. | `string` | `"main"` | no |
| <a name="input_plan_role_policy_arns"></a> [plan\_role\_policy\_arns](#input\_plan\_role\_policy\_arns) | IAM policy ARNs attached to the plan role. | `list(string)` | `[]` | no |
| <a name="input_apply_role_policy_arns"></a> [apply\_role\_policy\_arns](#input\_apply\_role\_policy\_arns) | IAM policy ARNs attached to the apply role. | `list(string)` | `[]` | no |
| <a name="input_plan_role_name"></a> [plan\_role\_name](#input\_plan\_role\_name) | (Optional) Name of the plan role. Defaults to "<github\_repo>-plan". | `string` | `null` | no |
| <a name="input_apply_role_name"></a> [apply\_role\_name](#input\_apply\_role\_name) | (Optional) Name of the apply role. Defaults to "<github\_repo>-apply". | `string` | `null` | no |
| <a name="input_role_path"></a> [role\_path](#input\_role\_path) | Path for both created roles. | `string` | `"/github-actions/"` | no |
| <a name="input_role_permissions_boundary"></a> [role\_permissions\_boundary](#input\_role\_permissions\_boundary) | (Optional) Permissions boundary ARN applied to both roles. | `string` | `null` | no |
| <a name="input_role_max_session_duration"></a> [role\_max\_session\_duration](#input\_role\_max\_session\_duration) | (Optional) Maximum session duration (seconds) for both roles. | `number` | `null` | no |
| <a name="input_additional_trust_conditions"></a> [additional\_trust\_conditions](#input\_additional\_trust\_conditions) | (Optional) Extra IAM condition blocks to tighten both roles' trust. A `StringEquals` block on `:sub`/`:aud` is rejected (it would merge-OR and widen); a different operator such as `StringNotEquals` is allowed. | <pre>list(object({<br>    test     = string<br>    variable = string<br>    values   = list(string)<br>  }))</pre> | `[]` | no |
| <a name="input_github_oidc_issuer"></a> [github\_oidc\_issuer](#input\_github\_oidc\_issuer) | OIDC issuer host used as the claim prefix. | `string` | `"token.actions.githubusercontent.com"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to both roles. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_plan_role"></a> [plan\_role](#output\_plan\_role) | The plan role. |
| <a name="output_apply_role"></a> [apply\_role](#output\_apply\_role) | The apply role. |
| <a name="output_plan_role_arn"></a> [plan\_role\_arn](#output\_plan\_role\_arn) | ARN of the plan role. |
| <a name="output_apply_role_arn"></a> [apply\_role\_arn](#output\_apply\_role\_arn) | ARN of the apply role. |
| <a name="output_subjects"></a> [subjects](#output\_subjects) | The exact OIDC subject each role trusts. |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

## Contribution

We welcome contribution, please checkout the [contribution guide](CONTRIBUTING.md). Be-aware we use [pre commit hooks](https://pre-commit.com/) to update the docs.

## Release

Releases are create automated from the main branch using conventional commit messages.

## Contact

For question you can reach out to one of the [maintainers](./MAINTAINERS.md).
