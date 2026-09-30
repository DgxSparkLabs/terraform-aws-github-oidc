variable "thumbprint_list" {
  description = "(Optional) Server certificate thumbprints for the OIDC provider. Leave null (default, recommended): with the aws provider ~> 6.0 this is Optional+Computed and AWS verifies GitHub's certificate chain itself, so thumbprints configured for this well-known issuer are effectively ignored. Set it only if you must pin thumbprints for a non-standard setup."
  type        = list(string)
  default     = null
}

variable "tags" {
  description = "A map of tags to add to the OIDC identity provider."
  type        = map(string)
  default     = {}
}
