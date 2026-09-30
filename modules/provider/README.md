# Terraform (sub) module to crate an OpenID Connect provider for GitHub

## Description

The module creates a OpenID Connect provider for GitHub. See for directions the [README](../../README.md) on top-level. See the [example](../../examples/default/README.md) for how to use the sub module.


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
| [aws_iam_openid_connect_provider.github_actions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_openid_connect_provider) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_thumbprint_list"></a> [thumbprint\_list](#input\_thumbprint\_list) | (Optional) Server certificate thumbprints for the OIDC provider. Leave null to let AWS manage the certificate chain automatically (recommended). | `list(string)` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to add to the OIDC identity provider. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_arn"></a> [arn](#output\_arn) | ARN of the OIDC provider, to pass as openid\_connect\_provider\_arn to the root module. |
| <a name="output_openid_connect_provider"></a> [openid\_connect\_provider](#output\_openid\_connect\_provider) | AWS OpenID Connect identity provider for GitHub Actions. |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
