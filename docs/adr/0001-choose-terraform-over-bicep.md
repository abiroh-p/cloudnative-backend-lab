# ADR 0001: Choose Terraform over Bicep

## Status
Accepted

## Context
Azure offers a native IaC tool (Bicep) and Terraform is a cloud-agnostic
third-party option. Both can provision the same resources.

## Decision
Use Terraform.

## Reasoning
- Terraform's HCL syntax and workflow (`plan` → `apply`) are used across
  AWS, GCP, and Azure — more transferable if a future role isn't
  Azure-specific.
- Most DevOps/platform job postings list "Terraform" explicitly far more
  often than "Bicep."
- The provider model (`azurerm`) is a good forcing function to understand
  Azure resources at the API level, rather than relying on Bicep's
  tighter (but Azure-only) abstractions.

## Trade-off acknowledged
Bicep has first-party Microsoft support and slightly faster feature parity
with new Azure services. For an Azure-only shop, Bicep can be the more
"native" choice. Worth knowing this trade-off exists even though Terraform
is the pick here.
