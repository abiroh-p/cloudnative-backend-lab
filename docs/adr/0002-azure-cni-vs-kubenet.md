# ADR 0002: Azure CNI over kubenet

## Status
Accepted

## Context
AKS supports two networking plugins: `kubenet` (simpler, pods get IPs from
a separate address space, NAT'd to the VNet) and `azure` CNI (pods get real
routable IPs directly from the VNet subnet).

## Decision
Use Azure CNI (`network_plugin = "azure"` in `terraform/main.tf`).

## Reasoning
- Pods getting real VNet IPs means NSGs, VNet peering, and other
  network-layer controls apply directly to pod traffic — this is the more
  "production-realistic" setup and the better one to learn on, since this
  project explicitly wants to cover cloud networking depth.
- kubenet requires more manual route table management as the cluster grows
  and has more networking gotchas in multi-node setups.

## Trade-off acknowledged
Azure CNI consumes more IP addresses from the VNet address space (one per
pod, not just per node) — this requires more deliberate subnet sizing.
kubenet is more IP-address-efficient and simpler for very small learning
clusters. Given the subnet was sized at `/24` (254 usable IPs) specifically
to accommodate this, it's a non-issue here, but worth knowing why the
subnet isn't smaller.

## Lessons learned during actual deployment

Two real issues came up applying this that are worth recording, since they
show the CNI/kubenet trade-off isn't just theoretical:

1. **Service CIDR must not overlap the VNet.** With Azure CNI, Kubernetes
   Services get virtual IPs from a separate range (not real VNet locations)
   — but Terraform's `azurerm_kubernetes_cluster` defaults that range to
   overlap the VNet's own address space if not set explicitly. This failed
   with `ServiceCidrOverlapExistingSubnetsCidr` until `service_cidr` and
   `dns_service_ip` were set explicitly to a disjoint range
   (`10.100.0.0/16`, outside the VNet's `10.0.0.0/16`). Confirmed after
   deploy: `az aks show --query networkProfile` reports `podCidr: null`
   under Azure CNI — pods get real VNet IPs directly, so there's no separate
   pod CIDR the way there would be under kubenet.

2. **Public IP quota is a real constraint of this networking mode.** AKS's
   `loadBalancerProfile` provisions at least one public IP for outbound
   node traffic by default (`outboundType: loadBalancer`). Student
   subscriptions cap public IPs at 3 per region — a leftover cluster from
   an earlier project (`canary-ml-platform-rg`) had already consumed one,
   which blocked this cluster's creation with `PublicIPCountLimitReached`
   until the old resource group was deleted. Worth remembering this quota
   exists before spinning up multiple clusters in the same subscription/
   region simultaneously.