# ADR 0006: Key Vault RBAC authorization over access policies

## Status
Accepted

## Context
Azure Key Vault supports two permission models:
- **Vault access policies** — Key Vault's original, own permission system,
  configured directly on the vault resource.
- **Azure RBAC** — the same role-assignment system used everywhere else in
  Azure (the same mechanism used to grant the app's identity access to
  other resources).

## Decision
Use RBAC (`enable_rbac_authorization = true`).

## Reasoning
- One less permission system to learn — RBAC is used everywhere else in
  this project already (implicitly, via `azurerm_role_assignment` being
  the standard Azure pattern).
- Microsoft's current documentation recommends RBAC for new vaults; access
  policies are the legacy model being phased toward deprecation.
- RBAC permissions integrate with Azure AD groups/conditional access more
  cleanly than vault-specific access policies.

## Trade-off acknowledged
Access policies allow slightly more fine-grained control in a few edge
cases (e.g., permissions scoped to a single secret rather than the whole
vault). For a project this size, that granularity isn't needed — role
assignments scoped to the whole vault (Secrets User for the app, Secrets
Officer for the developer) are sufficient.
