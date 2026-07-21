# ADR 0015: Azure Network Policy Manager over Calico; cluster recreation required

## Status
Accepted

## Context
Creating Kubernetes `NetworkPolicy` objects does nothing by itself —
enforcement requires an actual policy engine watching the cluster. Azure
CNI has no such engine by default. Two options exist: Azure's own Network
Policy Manager (`network_policy = "azure"`), or Calico
(`network_policy = "calico"`).

## Decision
Use Azure's own Network Policy Manager.

## Reasoning
This project's NetworkPolicy needs are simple, single-cluster,
pod-to-pod/namespace traffic restriction — exactly what Azure's built-in
engine handles. Calico adds real value for more advanced scenarios
(policies spanning multiple clusters, non-Kubernetes workloads, more
expressive rule syntax) that this project doesn't need. Fewer moving
parts, one less thing installed and maintained, for equivalent coverage
of what's actually being enforced here.

## Trade-off acknowledged
Calico is more commonly seen in multi-cloud/portable Kubernetes setups
(consistent with this project's general portability preference — see ADR
0001, ADR 0012). Azure's engine only works on AKS. For a project already
committed to AKS-specific choices in several other places (ACR, Key
Vault, Workload Identity), this one more Azure-specific dependency is a
reasonable trade for simplicity.

## Required cluster recreation
`network_policy` can only be set at AKS cluster CREATION time — it cannot
be toggled on an existing cluster via update. Enabling this required a
full `terraform destroy`/`apply` cycle on the AKS cluster (and everything
that depends on it: all Kubernetes objects, the ingress controller). This
is a genuine, known AKS limitation, not a mistake in how the cluster was
originally provisioned — network policy support is a foundational
networking decision AKS bakes in at cluster creation.

## Known limitation: egress rules are port-based, not IP-based
The `backend-app-policy` NetworkPolicy allows egress on ports 5432
(Postgres) and 443 (Key Vault/Azure AD) to ANY destination, not scoped to
specific IP ranges. This is a real, acknowledged gap — NetworkPolicy's
`ipBlock` selector could restrict this further to the Postgres subnet's
CIDR and Azure's published service tag ranges. It wasn't done here
because:
- The Postgres subnet CIDR is known and stable, but Key Vault/Azure AD
  endpoints resolve to Microsoft's broader, periodically-changing IP
  ranges — hardcoding those would create ongoing maintenance burden and
  risk breaking Workload Identity token exchange if Microsoft rotates
  ranges.
- The primary security boundary here is INGRESS (which pods can reach
  `backend-app` at all) — that is fully port-and-source restricted. The
  egress gap means a compromised `backend-app` pod could reach other
  services on 5432/443 beyond just its intended targets, which is a real
  but secondary risk compared to unrestricted ingress.

A production-grade tightening of this would use Azure Firewall or a
service-tag-aware policy engine for the egress side, rather than
NetworkPolicy's IP-block matching alone.
