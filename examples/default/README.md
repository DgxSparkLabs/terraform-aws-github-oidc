# Plan / apply roles for a single repository

This example creates the GitHub Actions OIDC provider (once per AWS account) and
two roles for one repository:

- a **plan** role, assumable only from the mainline branch
  (`refs/heads/<mainline_branch>`);
- an **apply** role, assumable from the configured GitHub **environment** —
  which you must protect separately (required reviewers + deployment-branch
  rules); the trust policy itself does not check the branch.

Both trust an exact, immutable OIDC subject
(`repo:<owner>@<owner_id>/<repo>@<repo_id>:...`). The module owns no permissions:
attach them externally via `plan_role_policy_arns` / `apply_role_policy_arns`.

## Usage

Set your repository's owner/repo names and their immutable numeric IDs, then:

```bash
terraform init
terraform apply
```

Wire the resulting ARNs into `aws-actions/configure-aws-credentials` in your
workflows. Each deployment job needs:

```yaml
permissions:
  id-token: write
  contents: read
```

Clean up with `terraform destroy`.
