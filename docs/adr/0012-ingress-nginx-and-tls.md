# ADR 0012: ingress-nginx over Azure-native ingress options, self-signed TLS reused

## Status
Accepted

## Context
AKS has no built-in Ingress controller. Options include the community
`ingress-nginx` project (installed via Helm, portable across any
Kubernetes cluster/cloud), or Azure-specific alternatives like the
Application Gateway Ingress Controller (AGIC) or the AKS-managed "Web App
Routing" add-on.

## Decision
Use `ingress-nginx`, installed via Helm.

## Reasoning
- Consistent with the same reasoning as ADR 0001 (Terraform over Bicep):
  portability. `ingress-nginx` works identically on AKS, EKS, GKE, or
  bare-metal — the skill transfers directly, unlike an Azure-specific
  controller.
- It's also literally the same technology (nginx) already used and
  understood from Stage 3 — the concepts (upstream, rate limiting, TLS
  termination) carry over directly, just expressed as Kubernetes
  annotations instead of a hand-written `nginx.conf`.
- It's the most widely used Ingress controller in the Kubernetes
  ecosystem generally, making it the safer default for a portfolio
  project meant to demonstrate broadly transferable skills.

## Trade-off acknowledged
AGIC integrates more tightly with Azure-native features (e.g., Web
Application Firewall via Application Gateway) that `ingress-nginx` doesn't
provide out of the box. A team fully committed to Azure might reasonably
choose AGIC for that integration. For learning general Kubernetes
patterns, `ingress-nginx`'s portability wins here.

## TLS: reusing the Stage 3 self-signed certificate
No real domain name points at this cluster — only a bare public IP from
the Load Balancer. Real TLS via cert-manager + Let's Encrypt requires a
domain to issue a certificate for, which doesn't exist here. Reusing the
same self-signed cert approach as Stage 3 (ADR 0009) keeps this
consistent: fine for proving the TLS termination mechanics work, not
representative of a real production setup. If a real domain were added
later, this is the exact point where cert-manager + Let's Encrypt would
replace the self-signed cert with a properly trusted, auto-renewing one.
