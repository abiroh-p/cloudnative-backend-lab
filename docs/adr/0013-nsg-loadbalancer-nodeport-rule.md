# ADR 0013: NSG rule required for LoadBalancer Service traffic (custom NSG gotcha)

## Status
Accepted

## Context
After installing ingress-nginx and getting a real public IP from Azure's
Load Balancer, both HTTP and HTTPS requests to that IP timed out
completely — not refused, not redirected, just hung until timeout.

## Root cause
A Kubernetes `LoadBalancer`-type Service (the ingress-nginx controller's
Service) works by Azure's Load Balancer receiving internet traffic and
DNAT-ing it to a **NodePort** on one of the AKS nodes
(`kubectl get svc` showed `443:31144/TCP` — `31144` is the NodePort).
That forwarded packet arrives at the node's network interface still
carrying the **original client's source IP** — Azure's Standard Load
Balancer preserves source IP rather than masquerading traffic as coming
from "the load balancer" itself.

This project attached a CUSTOM network security group to the AKS subnet
back in Stage 0 (`azurerm_network_security_group.aks`), with zero
explicit rules — relying entirely on Azure's default NSG rules. The
default `AllowAzureLoadBalancerInBound` rule does NOT cover this
scenario — it only recognizes Azure's own internal health-probe traffic,
not client traffic forwarded through the LB to a NodePort. With no
matching allow rule, the NSG's default `DenyAllInBound` catch-all silently
dropped every real request.

## Decision
Add an explicit NSG rule allowing inbound TCP traffic from `Internet` on
the Kubernetes NodePort range (`30000-32767`).

## Why this wasn't caught earlier
Every previous test of this cluster used either direct `kubectl exec`
access (bypasses the network path entirely) or `kubectl port-forward`
(tunnels through the Kubernetes API server, which is a completely
different network path that doesn't touch this NSG at all). This is the
FIRST time in the whole project that traffic actually needed to enter the
cluster from the public internet through the data-plane Load Balancer —
which is exactly why this gap stayed invisible until now.

## Lesson
This is specifically a consequence of bringing your OWN NSG to an AKS
subnet instead of letting AKS fully manage its own networking. Clusters
that don't attach a custom NSG don't need this rule added manually —
AKS's own automatically-managed NSG (on the node resource group, a
different NSG entirely from the one this project created) handles it
without any action needed. Choosing to manage the subnet's NSG explicitly
(for the learning value of understanding VNet/NSG concepts directly) came
with the responsibility of getting rules like this right — a trade-off
worth having eyes open about.
