# Stage 0 — IaC Foundation

This provisions the base infrastructure your backend project will run on:
a Resource Group, a VNet with two subnets (AKS + public), an NSG, and a
minimal AKS cluster.

## What gets created

| Resource | Purpose |
|---|---|
| Resource Group | Container for everything else |
| Virtual Network (`10.0.0.0/16`) | Your private network in Azure |
| AKS subnet (`10.0.1.0/24`) | Where your Kubernetes nodes live |
| Public subnet (`10.0.2.0/24`) | Reserved for Nginx/ingress in a later stage |
| Network Security Group | Firewall on the AKS subnet (currently minimal — tightened later) |
| AKS cluster | 1-node cluster, `Standard_B2s` size, Azure CNI networking |

## Prerequisites

```bash
# Install Terraform (if not already available in your devcontainer)
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install terraform

# Install Azure CLI (if not already available)
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Log in — this opens a browser link/device code flow
az login
```

## Running it

```bash
cd terraform
terraform init      # downloads the azurerm provider
terraform plan       # shows you EXACTLY what will be created — read this before apply
terraform apply       # creates the resources — type "yes" to confirm
```

`terraform plan` is worth actually reading line by line the first time —
it's the single best way to build intuition for what each resource block
actually produces in Azure.

After apply finishes:

```bash
# Connect kubectl to your new cluster
az aks get-credentials --resource-group cloudbe-dev-rg --name cloudbe-dev-aks

# Verify
kubectl get nodes
```

## Tearing down

Since this is running against student credits, tear it down when you're not
actively working on it:

```bash
terraform destroy
```

This is itself a useful habit — cost governance (Stage 6 in the learning
plan) starts with not leaving idle clusters running.

## What's intentionally simplified right now (and why)

- **Local state, not remote state** — fine solo, not fine on a team. Flagged
  in `providers.tf` with the commented-out backend block for when you're
  ready.
- **1 AKS node, no autoscaling yet** — Cluster Autoscaler / HPA come in
  later once you have an app generating real load to scale against.
- **NSG has no explicit allow rules yet** — you'll add a real rule when
  Nginx/ingress in the public subnet needs to reach the AKS subnet
  (Stage 3). Right now it's just the boundary.
- **No Key Vault / managed identity wiring yet** — that's Stage 2, once you
  have a database with real credentials to protect.

## Industry-standard patterns already reflected here

- **Provider version pinning** (`providers.tf`) — prevents silent breaking
  changes.
- **Resource naming convention** — `<project>-<env>-<resource>` is close to
  Microsoft's own Cloud Adoption Framework (CAF) naming recommendations.
- **Variables instead of hardcoded values** — makes the same config reusable
  across dev/staging/prod by just changing `environment`.
- **Tags on resources** — real orgs use tags for cost allocation and
  ownership tracking; we're doing it from the start rather than bolting it
  on later.
