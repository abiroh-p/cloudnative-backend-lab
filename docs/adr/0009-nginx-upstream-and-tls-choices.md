# ADR 0009: Explicit nginx upstream list + self-signed TLS for local dev

## Status
Accepted

## Context
Two decisions needed for the Stage 3 nginx layer: how the load-balanced
backend pool is defined, and how TLS is terminated locally.

## Decision 1: Explicit `server app1:8000; server app2:8000;` in the upstream block

## Reasoning
nginx resolves upstream hostnames ONCE at container startup and caches the
result — it does not automatically pick up new replicas the way Docker's
embedded DNS round-robin does for some other proxies. Listing servers
explicitly also makes the load-balanced pool visible and debuggable: you
can see exactly which two backends nginx is choosing between, rather than
trusting DNS behavior you can't directly inspect.

## Trade-off acknowledged
This doesn't scale elastically — adding a third replica means editing
`nginx.conf` and rebuilding the nginx image, not just spinning up another
container. In Kubernetes (Stage 4), a Service + Ingress replaces this
entirely: Kubernetes' own Service abstraction handles dynamic backend
discovery, and nginx (or whatever ingress controller is used) integrates
with that natively. This explicit-list approach is specifically a
local-learning-stage choice, not the long-term design.

## Decision 2: Self-signed TLS certificate, generated locally, not committed to git

## Reasoning
- A private key is exactly as sensitive as a password — it must never be
  committed to version control. `nginx/generate-certs.sh` generates one
  locally per-developer; `nginx/certs/` is gitignored.
- Self-signed is sufficient to exercise the actual mechanics that matter
  for learning: TLS termination at the proxy, HTTP→HTTPS redirect, and the
  `X-Forwarded-Proto` header pattern — without needing a real domain name
  or a Certificate Authority for local-only traffic.

## Trade-off acknowledged
Browsers and `curl` will correctly flag a self-signed cert as untrusted
(`curl -k` needed to bypass the warning for testing). This is expected and
fine for localhost — it is NOT how a real deployment should look. A real
deployment (or even Stage 4, if a public endpoint is added) should use a
real CA — most commonly via cert-manager + Let's Encrypt in Kubernetes,
issuing and auto-renewing certificates for a real domain automatically.
