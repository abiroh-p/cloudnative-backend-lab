# ADR 0010: ACR with admin_enabled=false, pull access via kubelet identity

## Status
Accepted

## Context
Azure Container Registry supports two pull-access models: a static
admin username/password (`admin_enabled = true`), or role-based access via
Azure AD identities (RBAC role assignment).

## Decision
`admin_enabled = false`. Grant pull access via an `AcrPull` role
assignment to AKS's **kubelet identity** specifically.

## Reasoning
- Consistent with every other credential decision in this project
  (Postgres random password + Key Vault, Key Vault RBAC, Workload
  Identity for the app) — no static secret exists anywhere that could
  leak.
- AKS actually has TWO separate identities: the cluster's own
  system-assigned identity (control plane) set via the `identity {}`
  block, and a separate **kubelet identity** that the nodes use for
  node-level operations like pulling images. These are easy to conflate —
  granting `AcrPull` to the wrong one produces a confusing
  `ImagePullBackOff` error with no obvious clue that the identity, not the
  image or registry, is the problem.

## Trade-off acknowledged
Registry admin credentials are occasionally still convenient for quick
manual `docker login` from a laptop outside any Azure-authenticated
context. Since this project's Terraform-driven workflow always has `az
login` available, that convenience isn't needed here.
