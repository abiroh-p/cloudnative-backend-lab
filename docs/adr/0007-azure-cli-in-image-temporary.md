# ADR 0007: Install azure-cli in the app image (temporary, local-dev-only)

## Status
Accepted (temporary — see "Revisit" below)

## Context
`DefaultAzureCredential` (used to authenticate to Key Vault) tries several
credential sources in order. Locally, the intended fallback is
`AzureCliCredential` — but this credential type works by **shelling out to
the `az` binary**, not by reading `~/.azure`'s token cache files directly.
The app's Docker image (`python:3.12-slim`) has no CLI tools installed, so
even with the host's `~/.azure` directory mounted in
(`docker-compose.yml`), authentication failed with
`Azure CLI not found on path`.

## Decision
Install `azure-cli` via pip in the Dockerfile.

## Reasoning
Keeps `DefaultAzureCredential`'s "same code works everywhere" property
intact for local testing, without introducing a second, competing
authentication concept (e.g., a Service Principal + client secret) just
for local dev — which would need its own secret-protection story and
would muddy the Workload Identity concept this stage is actually trying to
teach.

## Trade-off acknowledged
This adds meaningful size to the image (~150-200MB) for a capability
**production never uses** — once this app runs in AKS (Stage 4), Workload
Identity authenticates via `ManagedIdentityCredential`, which needs no CLI
binary at all. Shipping `az` in a production image is genuinely wasteful
and a minor attack-surface increase.

## Revisit
When the Dockerfile is revisited in Stage 4 for real (image size / ACR
scan results start to matter), split into a multi-stage build: a `dev`
stage with `azure-cli` for local testing, and a `production` stage without
it, built via a Docker build target (`docker build --target production`).
