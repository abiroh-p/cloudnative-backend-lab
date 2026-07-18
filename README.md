# cloudnative-backend-lab

A hands-on backend + cloud infrastructure project built stage by stage on
Azure (AKS), covering IaC, networking, database operations, deployment
strategies, and observability — with the reasoning behind each decision
documented in `docs/adr/` as I go.

## Why this project exists

Built to go deep on cloud computing fundamentals for backend / DevOps /
MLOps roles — not just to have a deployed app, but to deliberately touch
the breadth of topics a cloud engineering interview would probe: compute,
networking, storage, identity/security, deployment strategy, and
observability. See `docs/architecture.md` for the full learning-outcomes
map.

## Stages

| Stage | Folder | Status | Covers |
|---|---|---|---|
| 0 — IaC foundation | `terraform/` | ✅ done | Resource Group, VNet, subnets, NSG, AKS skeleton |
| 1 — Backend core | `app/` | ⬜ not started | FastAPI service, structured logging |
| 2 — Database + secrets | `app/`, `terraform/` | ⬜ not started | Postgres, Alembic, Key Vault, managed identity |
| 3 — Networking layer | `nginx/`, `terraform/` | ⬜ not started | Nginx, TLS, public/private subnet split |
| 4 — Kubernetes + networking | `k8s/` | ⬜ not started | Ingress, NetworkPolicy, RBAC, ACR scanning |
| 5 — Deployment strategies + CI/CD | `k8s/rollouts/`, `.github/workflows/` | ⬜ not started | Rolling, blue-green, canary; GitHub Actions pipeline |
| 6 — Observability + cost | `observability/` | ⬜ not started | Prometheus/Grafana, OpenTelemetry, resource tagging |

## Getting started (Stage 0)

See [`terraform/README.md`](terraform/README.md) for setup and run
instructions.

## Architecture decisions

Every non-obvious choice (Terraform vs Bicep, Azure CNI vs kubenet, which
deployment strategy, etc.) is written up as an ADR in `docs/adr/` — read
these to understand *why*, not just *what*.
