# ADR 0014: External Ingress connectivity unresolved — documented, not solved

## Status
Open / Blocked

## Context
After installing ingress-nginx and provisioning a public LoadBalancer IP,
external HTTPS/HTTP requests to that IP time out completely, despite:

- Two NSG layers verified and fixed (subnet-level `cloudbe-aks-nsg` and the
  AKS-managed VMSS-level `aks-agentpool-*-nsg`), each given an explicit
  rule allowing inbound TCP on the Kubernetes NodePort range from the
  internet
- Azure's own Load Balancer metrics reporting `Health Probe Status: 100`
  and `Data Path Availability: 100` — the platform's own signal says the
  backend is healthy and reachable
- In-cluster connectivity fully confirmed working end-to-end (a debug pod
  hitting the ingress controller's Service via internal cluster DNS
  received a correct `200` response with real data, full TLS handshake
  succeeding)
- The node confirmed stable and `Ready` on its current VMSS instance
- A complete clean reset — deleting and recreating the LoadBalancer
  Service from scratch, yielding a brand new public IP and new NodePorts —
  reproduced the identical timeout

Tested from three independent client networks (a GitHub Codespace, a
phone on cellular data, and a separate laptop), all with the same result,
ruling out a client-side or single-network cause.

## What this rules out
- NSG misconfiguration (verified and fixed at both layers; the fixes were
  real and are still correct to keep)
- A stale/stuck IP or LB provisioning state (a full clean reset reproduced
  the same failure on a fresh IP)
- Client-side network restrictions (three independent networks all fail
  identically)
- The application, Ingress routing, or TLS configuration itself (proven
  working via in-cluster testing)
- **ingress-nginx's configuration specifically** — a completely plain
  `LoadBalancer`-type Service (no ingress-nginx, no TLS, pointing directly
  at the `backend-app` Deployment) was tested on a THIRD independent
  public IP (`98.70.247.39`) and produced the identical connection
  timeout. This is the most conclusive test run: it proves the issue is
  universal to any `LoadBalancer` Service on this cluster, not specific
  to ingress-nginx's Helm chart, annotations, or configuration.
- **`externalTrafficPolicy: Cluster` specifically** — switched to
  `Local` (a genuinely different code path: a dedicated per-node health
  check port instead of the generic kube-proxy-based mechanism, plus one
  fewer internal network hop). Same timeout result.

## Full checklist of what was verified clean via Azure CLI
Beyond the above, every one of these was individually inspected and
confirmed correct or healthy, with no anomaly found:
- Both NSG layers (subnet-level and VMSS-level), each with the correct
  explicit allow rule
- Node health and stability (confirmed Ready, stable across a node
  replacement event)
- Load Balancer rules and health probes (correct ports, correct protocol,
  matching NodePorts)
- Azure's own `Health Probe Status` and `Data Path Availability` metrics
  (100% throughout)
- The Load Balancer's outbound rule configuration
- The Public IP resource itself (SKU, zones, DDoS settings, tags — all
  standard, no anomalies)

## Conclusion
This is very likely a subscription- or platform-level restriction on
inbound internet traffic to Standard Load Balancers, specific to this
Azure for Students subscription or cluster/region combination — not a
configuration error in this project. Three consecutive, independently
provisioned LoadBalancer Services (ingress-nginx's original IP, its
recreated fresh IP, and a completely separate plain diagnostic Service)
all failed identically despite Azure's own health metrics reporting the
backend as fully healthy.

## What remains unconfirmed
- Whether this is an undocumented Azure for Students subscription
  restriction on inbound internet traffic to a Standard Load Balancer
  (searched — found no direct documentation of this, only the
  well-documented outbound SMTP port 25 block, which is unrelated)
- Whether this is a platform-level issue specific to this cluster/region
  combination

## Decision
Document this honestly rather than continue indefinite trial-and-error.
The deployment itself (AKS, ACR, Postgres, Key Vault, Workload Identity,
the Deployment/Service/migration Job) is fully proven working via
`kubectl port-forward` — see Stage 4b. Only the public entry point via
Ingress/LoadBalancer remains blocked, and it has been investigated as
thoroughly as CLI-level tooling allows. Further debugging attempts are
not planned unless new information becomes available (e.g., an Azure
support response, or the issue resolving on its own over time).

## Next steps (not yet attempted)
- Open an Azure support/community question with the specific symptom
  (health probe healthy, data path healthy, but external TCP connection
  times out) — this combination is unusual enough that Azure support may
  recognize it immediately
- Retry after some elapsed time — if this is a transient platform-side
  issue, it may self-resolve
- As a diagnostic (not a fix): try provisioning a plain `LoadBalancer`
  type Service directly (bypassing ingress-nginx entirely) pointing at
  the backend-app Deployment, to see whether the issue is specific to the
  ingress-nginx chart's configuration or affects ANY LoadBalancer Service
  on this cluster
