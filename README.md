# Terraform module — AWS OIDC plan/apply roles for GitHub Actions

This [Terraform](https://www.terraform.io/) module manages OpenID Connect (OIDC)
integration between [GitHub Actions and AWS](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services).

It is an opinionated fork of
[philips-labs/terraform-aws-github-oidc](https://github.com/philips-labs/terraform-aws-github-oidc)
reshaped for a hardened two-role plan/apply workflow.

## Description

For one repository the module creates **two roles**:

- **plan** — by default assumable only from the mainline branch
  (`sub` = `repo:<owner>@<owner_id>/<repo>@<repo_id>:ref:refs/heads/<mainline_branch>`).
  With `plan_trusts_pull_requests = true` it also trusts the `:pull_request`
  subject (see [Pull-request plans](#pull-request-plans-opt-in)).
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

## Pull-request plans (opt-in)

By default the plan role trusts only pushes to the mainline branch, so a
`pull_request` job cannot assume it (its subject is `...:pull_request`, which
does not match). Set `plan_trusts_pull_requests = true` to also trust the
`pull_request` subject so PRs can compute a read-only plan.

Caveats:

- AWS trust policies can only match `sub`/`aud` — not `base_ref`, `event_name`,
  or `head_ref`. So this trusts **every same-repo pull request, on any base
  branch**, not just PRs into the mainline branch. Keep the plan role strictly
  read-only.
- The `pull_request` subject is only present when the job sets **no**
  `environment:`. A plan job bound to an environment gets
  `...:environment:<name>` instead and will not match.
- **Forks are not distinguished by the trust policy.** A fork PR's token carries
  the *base* repo's `...:pull_request` subject, so it would match the plan role.
  What normally keeps forks out is that GitHub does not grant `id-token: write`
  to fork-PR workflows **by default** — but an org/repo admin can enable it, and
  then fork PRs can assume the plan role. The module cannot tell. Keep that
  default, keep the plan role read-only, and do not use `pull_request_target`.
- **Keep the apply job push-only.** Do not add `pull_request` to a workflow
  whose apply job sets `environment:` — that job's `sub` becomes
  `...:environment:<name>`, which matches the **write** apply role, so a PR could
  assume it. Gate the apply job with `if: github.event_name == 'push'` (as the
  [example](examples/repositories/plan-apply/.github/workflows/terraform.yml)
  does).

## Migrating from philips-labs/terraform-aws-github-oidc

This fork changes the interface. Key differences when upgrading:

- One repo now yields **two roles** (`plan`, `apply`) instead of one.
- `repo` is replaced by `github_owner` + `github_repo` + the immutable numeric
  `github_owner_id` + `github_repo_id`.
- `role_policy_arns` is replaced by `plan_role_policy_arns` /
  `apply_role_policy_arns`.
- `default_conditions` / `conditions` / `github_environments` are gone; the plan
  and apply subjects derive from `mainline_branch` and `apply_environment`.
- Trust-widening inputs (`account_ids`, `custom_principal_arns`, `allow_all`) are
  removed; `additional_trust_conditions` remains for tightening only.
- Outputs `role` / `conditions` become `plan_role` / `apply_role` /
  `plan_role_arn` / `apply_role_arn` / `subjects`.
- The provider submodule defaults `thumbprint_list` to `null` (AWS-managed) and
  requires the `aws` provider `~> 6.0`.
- **Prerequisite:** the repo must emit the immutable subject (created/renamed/
  transferred on or after 2026-07-15, or opted in); legacy name-only repos are
  denied until they adopt it.

## Examples

- Terraform: [`examples/default`](examples/default/README.md) — provider + plan/apply roles for one repository.
- GitHub Actions consumer: [`examples/repositories/plan-apply`](examples/repositories/plan-apply/README.md) — a workflow that assumes the plan role on a push to main and the apply role from a protected environment.

## How it works

**Purpose.** Let GitHub Actions obtain **temporary AWS credentials with no stored
secrets**, by creating two tightly-scoped IAM roles that only *your* repo's
pipeline can assume.

**The problem it removes.** Instead of long-lived `AWS_ACCESS_KEY_ID`/`SECRET` in
GitHub secrets (which never expire and leak easily), this uses **OIDC
federation**: GitHub signs a short-lived token describing the workflow, AWS
trusts GitHub, and returns credentials that live ~1 hour.

**The trust check — a bouncer reading a badge.** Every workflow run gets a signed
OIDC token whose key field is the **`sub` (subject)**, e.g.
`repo:my-org@111/my-repo@222:ref:refs/heads/main`. Each role's trust policy
requires the `sub` to equal one exact string (`StringEquals`, no wildcards) and
the audience to be `sts.amazonaws.com`. The `@111`/`@222` are GitHub's
**immutable** owner/repo IDs, so recycling an org/repo *name* cannot forge a match.

**Two roles, and why:**

| Role | Trusts (who can use it) | Meant for |
|---|---|---|
| **plan** | `…:ref:refs/heads/<mainline_branch>` (a push to main) | `terraform plan` — read-only preview |
| **apply** | `…:environment:<apply_environment>` (a job bound to a protected Environment) | `terraform apply` — changing infra |

Splitting them gives **separation of duties + a human gate**: the plan role
carries only read permissions; the apply role carries write and can only be
reached through a GitHub **Environment** you protect with required reviewers and
deployment-branch rules.

**What the module makes vs. what you bring.** It creates the OIDC provider (once
per account, via `modules/provider`) and the two roles with their trust policies.
It owns **no permissions** — you pass your own IAM policy ARNs via
`plan_role_policy_arns` / `apply_role_policy_arns` and it attaches them.

**End-to-end flow.** (1) Terraform creates the provider + roles; you attach
read-only/write policies. (2) It outputs `plan_role_arn` / `apply_role_arn`, which
you store as GitHub Actions **variables** (not secret). (3) A push to `main` runs
the plan job → token `sub = …:ref:refs/heads/main` → assumes the plan role → 1-hour
creds → `terraform plan`. (4) The apply job is bound to the Environment → GitHub
gates it → after approval, token `sub = …:environment:<env>` → assumes the apply
role → `terraform apply`.

**Safety rails:** exact `StringEquals` (no wildcards); immutable owner/repo IDs;
no baked-in permissions; apply gated by an Environment (and, in the example,
pinned to `push` so a PR can never reach the write role); a 64-char role-name
`precondition`; and `additional_trust_conditions` that rejects attempts to loosen
the `sub`/`aud` claims. PR previews are opt-in (`plan_trusts_pull_requests`).

## Daily usage for engineers

Once set up, most engineers never think about AWS credentials. The plumbing is
invisible on a good day; when it surfaces, it surfaces as a clear gate or a
self-explanatory error.

**Two kinds of user.** The **platform/infra engineer** touches the *module* once
(create provider + roles, attach policies, paste the two role ARNs into Actions
variables), then rarely again. The **application engineer** never touches the
module or AWS credentials — they write code and open PRs.

**A day in the life (app engineer):**

- **Local work** uses their *own* AWS login (e.g. `aws sso login`). The module
  changes nothing about local `terraform plan`; it is only about the CI robot's
  identity.
- **Open a PR.** Keyless checks (`fmt`, `validate`, lint) run. With the shipped
  workflow the PR job simply does **not** run a cloud plan (the plan role trusts
  only pushes to main), so there is nothing to fail. A cloud plan diff on PRs
  appears **only if the team opts in on all three fronts**: set
  `plan_trusts_pull_requests = true`, **uncomment** the `pull_request:` trigger in
  the workflow, and keep the plan job free of any `environment:`.
- **Merge to `main`.** The plan job runs automatically and saves a plan artifact.
  Still no credential handling by the engineer.
- **The apply gate.** The apply job pauses at the Environment showing *"Waiting for
  review."* An approver clicks **Approve**; only then does the job assume the write
  role and apply exactly the reviewed plan.

So the loop is: **push → auto plan → approve → apply.** The engineer's job is
"write code, open PR, (maybe) click approve."

**When it becomes visible (and what it means):**

- *"Waiting for review" on apply* — not an error; the Environment gate doing its job.
- *A PR can't assume a role* — only happens if someone added a `pull_request`
  trigger while plan-on-PR is off; with the shipped workflow the PR job doesn't run.
- *Assume fails right after onboarding a repo* — usually the immutable-subject
  prerequisite: enable it on the repo/org (one-time setting).
- *A too-long role name* — surfaces to the **platform engineer when they apply the
  module** (the 64-char `precondition`), telling them to set
  `plan_role_name`/`apply_role_name`. App engineers don't hit this in CI.
- *A plan job that sets `environment:` stops matching the plan role* — by design;
  the environment changes the subject to `:environment:…` (the apply shape).

**What engineers no longer do:** no AWS keys in GitHub secrets; no manual
`assume-role`; no shared prod deploy key; no standing credentials — CI's creds
expire in ~an hour.


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
| <a name="input_plan_trusts_pull_requests"></a> [plan\_trusts\_pull\_requests](#input\_plan\_trusts\_pull\_requests) | (Optional) Also trust the `pull_request` subject on the plan role so PRs can compute a read-only plan. Trusts every same-repo PR on any base branch; keep the plan role read-only. | `bool` | `false` | no |
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
| <a name="output_subjects"></a> [subjects](#output\_subjects) | The exact OIDC subjects each role trusts. |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

## Contribution

We welcome contribution, please checkout the [contribution guide](CONTRIBUTING.md). Be-aware we use [pre commit hooks](https://pre-commit.com/) to update the docs.

## Release

Releases are create automated from the main branch using conventional commit messages.

## Contact

For question you can reach out to one of the [maintainers](./MAINTAINERS.md).
