# Example consumer workflow — plan / apply

[`terraform.yml`](.github/workflows/terraform.yml) shows a repository using the
two roles created by this module:

- The **plan** job runs on a push to the mainline branch and assumes the
  read-only plan role (`plan_role_arn`). It can optionally also run on pull
  requests — see [Plans on pull requests (opt-in)](#plans-on-pull-requests-opt-in).
- The **apply** job is bound to a protected GitHub **environment** and assumes
  the write apply role (`apply_role_arn`). Protect that environment with
  required reviewers so the apply gates on human approval.

Because both roles use an exact `StringEquals` subject match, the job's trigger
must line up with the trusted subject: the plan job must run from the mainline
branch, and the apply job must run in the configured environment. Store the two
role ARNs as Actions variables (`AWS_PLAN_ROLE_ARN`, `AWS_APPLY_ROLE_ARN`); they
are not secret.

## Plans on pull requests (opt-in)

To also run the plan job on pull requests, set `plan_trusts_pull_requests = true`
on the module and uncomment the `pull_request:` trigger in the workflow. The plan
job must set **no** `environment:` (otherwise its subject becomes
`...:environment:<name>` and will not match). Keep the **apply** job push-only
(`if: github.event_name == 'push'`): a job that sets `environment:` gets the
`:environment:<name>` subject, which matches the **write** apply role, so it must
never run on a PR. Note this trusts every same-repo pull request on any base
branch — keep the plan role strictly read-only. See the root README's
"Pull-request plans (opt-in)" section for the caveats.
