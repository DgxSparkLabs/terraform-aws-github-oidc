# Example consumer workflow — plan / apply

[`terraform.yml`](.github/workflows/terraform.yml) shows a repository using the
two roles created by this module:

- The **plan** job runs on a push to the mainline branch and assumes the
  read-only plan role (`plan_role_arn`).
- The **apply** job is bound to a protected GitHub **environment** and assumes
  the write apply role (`apply_role_arn`). Protect that environment with
  required reviewers so the apply gates on human approval.

Because both roles use an exact `StringEquals` subject match, the job's trigger
must line up with the trusted subject: the plan job must run from the mainline
branch, and the apply job must run in the configured environment. Store the two
role ARNs as Actions variables (`AWS_PLAN_ROLE_ARN`, `AWS_APPLY_ROLE_ARN`); they
are not secret.
