# k8s/ — Stage 4: Kubernetes deployment

Real Pods running in AKS, using Workload Identity for Key Vault access —
no `.env`, no mounted `az login` session, no local-dev workarounds. This
is the environment everything since Stage 2 has been building toward.

## Prerequisites

- `terraform apply` already run (Stage 0-4a resources exist: AKS, ACR,
  Postgres, Key Vault, the app's Managed Identity + federated credential)
- App image built and pushed to ACR (`backend-app:v1`)
- `kubectl` pointed at your cluster:
  ```bash
  az aks get-credentials --resource-group cloudbe-dev-rg --name cloudbe-dev-aks
  ```
- `envsubst` available (part of `gettext-base`):
  ```bash
  sudo apt-get install -y gettext-base   # if not already present
  ```

## Deploy

```bash
cd k8s
chmod +x deploy.sh
./deploy.sh
```

Watch the output — it applies ServiceAccount and ConfigMap first, then
runs the migration Job **and waits for it to complete** before touching
the Deployment at all. If the migration Job fails, the script stops there
rather than deploying app Pods against a schema that might not be ready.

## Verify

```bash
kubectl get pods,svc,jobs
```

You should see: the `backend-app-migrate` Job showing `Completed`, two
`backend-app-*` Pods showing `Running` with `READY 1/1`, and a
`backend-app` Service of type `ClusterIP`.

**Check that Workload Identity actually worked** (the real test of this
whole stage):

```bash
kubectl logs deployment/backend-app | grep -E 'fetching_secret_from_key_vault|secret_fetch_succeeded'
```

You should see the same log lines as local dev — except this time there's
no mounted `~/.azure`, no `az login` fallback, and no `azure-cli` in this
image at all (check `app/Dockerfile` — it's still there since the same
image is used locally and in AKS; Stage 4's multi-stage build cleanup,
flagged back in ADR 0007, is the natural next thing to do once this is
confirmed working). The credential chain should show
`ManagedIdentityCredential`/`WorkloadIdentityCredential` succeeding
instead of `AzureCliCredential` this time — proof the actual production
auth path works, not just the local fallback.

## Try the app (before Ingress exists)

No public endpoint yet — that's the next sub-stage. For now, reach it via
port-forward:

```bash
kubectl port-forward svc/backend-app 8080:80
```

In another terminal:
```bash
curl http://localhost:8080/items
```

## What's deliberately incomplete right now

- **No Ingress yet** — the Service is ClusterIP-only, reachable only via
  port-forward. Next sub-stage replaces local nginx with a real Ingress
  controller.
- **Postgres is still publicly accessible** (ADR 0005's temporary
  decision) — now that the app genuinely runs inside the VNet via AKS,
  this is the point where that gets revisited for real.
- **No NetworkPolicy yet** — any pod in the cluster can currently reach
  any other pod.
- **Image tag `v1` is static**, reused on every rebuild — real CI/CD
  (Stage 5) uses unique tags per build instead.
