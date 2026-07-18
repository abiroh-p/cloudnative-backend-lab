# ADR 0005: Public access + open firewall rule for Postgres (temporary)

## Status
Accepted (temporary — see "Revisit" below)

## Context
Azure Database for PostgreSQL Flexible Server supports two connectivity
models:
- **Private access (VNet integration)** — the server gets an address
  inside your VNet via a delegated subnet, reachable only from resources
  inside that VNet (or peered/connected networks). No public internet path
  exists at all.
- **Public access** — the server gets a public endpoint, restricted by
  firewall rules (allowed IP ranges).

## Decision
Use public access with a wide-open firewall rule (`0.0.0.0` –
`255.255.255.255`) for this stage.

## Reasoning
This is a **deliberate simplification for learning, not a production
pattern.** The reason: development right now happens locally via
docker-compose in a GitHub Codespace, which is NOT inside the Azure VNet.
If private-access-only were used now, the app running locally would have
no path to reach the database at all — you'd need a VPN, bastion host, or
similar just to keep developing, which is a lot of networking complexity
to front-load before the basics (Key Vault, managed identity, migrations
against a real managed DB) are even working.

## Trade-off acknowledged (explicitly, not glossed over)
An open firewall rule on a database is a real security problem in any
setting other than "throwaway learning environment protected by a strong
generated password." This is acceptable ONLY because:
- The password is a 24-character random value from Terraform
  (`random_password`), never hardcoded
- This is a student subscription with no real user data
- It's explicitly temporary — see below

## Revisit
Once Stage 4 (AKS deployment) is reached, the app will run inside the same
VNet as the database. At that point:
1. Add a delegated subnet for Postgres (`Microsoft.DBforPostgreSQL/flexibleServers`)
2. Add a private DNS zone linked to the VNet
3. Recreate the server with `public_network_access_enabled = false` and
   `delegated_subnet_id` set
4. Remove the wide-open firewall rule entirely

This is intentionally sequenced as a later, separate change rather than
solved upfront, so the private-networking concepts land at the point
they're actually needed — matching how a real project would evolve its
security posture as deployment targets change.
