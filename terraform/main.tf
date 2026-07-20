# ============================================================
# RESOURCE GROUP
# ============================================================
# WHY: Azure organizes everything into Resource Groups — a logical container
# for resources that share a lifecycle (created/deleted together). Industry
# convention: name it with a pattern like <project>-<env>-rg so it's
# instantly identifiable in a subscription with many resources.

resource "azurerm_resource_group" "main" {
  name     = "${var.project_name}-${var.environment}-rg"
  location = var.location
}

# ============================================================
# VIRTUAL NETWORK
# ============================================================
# WHY: A VNet is your private network inside Azure — nothing outside it can
# reach resources inside unless you explicitly allow it. This is the
# foundation of the "cloud networking" topics you wanted to cover.

resource "azurerm_virtual_network" "main" {
  name                = "${var.project_name}-${var.environment}-vnet"
  address_space       = var.vnet_address_space
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

# ============================================================
# SUBNETS
# ============================================================
# WHY: Subnets carve the VNet into smaller network segments so you can apply
# different rules to different tiers of your app. Standard pattern:
# - a "private" subnet for things that should never be reached from the
#   public internet directly (your app, your DB, your AKS nodes)
# - a "public" subnet for the thing that DOES need to be internet-facing
#   (load balancer / ingress / Nginx) — you'll use this in Stage 3

resource "azurerm_subnet" "aks" {
  name                 = "${var.project_name}-aks-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = var.aks_subnet_address_prefix
}

resource "azurerm_subnet" "public" {
  name                 = "${var.project_name}-public-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = var.public_subnet_address_prefix
}

# ============================================================
# DELEGATED SUBNET FOR POSTGRES — private VNet integration
# ============================================================
# WHY "delegated": Azure requires a subnet to be explicitly delegated to
# a specific service before that service can inject its own resources
# (like a Postgres Flexible Server) directly into your VNet with a
# private, non-internet-routable address. The delegation is what tells
# Azure "this subnet's IP space belongs to Postgres Flexible Server
# instances, not general-purpose VMs/pods." This replaces the temporary
# public-access approach from ADR 0005, now that the app runs inside the
# VNet (via AKS) and no longer needs internet-routable access to reach it.
resource "azurerm_subnet" "postgres" {
  name                 = "${var.project_name}-postgres-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = var.postgres_subnet_address_prefix

  delegation {
    name = "postgres-flexible-server-delegation"
    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# ============================================================
# PRIVATE DNS ZONE — lets VNet resources resolve the server's hostname
# ============================================================
# WHY this is needed: with public access disabled, the server's hostname
# no longer resolves via normal public DNS. This private zone, linked to
# the VNet below, is what lets anything INSIDE the VNet (your AKS pods)
# resolve "<servername>.postgres.database.azure.com" to the server's
# private IP. Anything OUTSIDE the VNet (like local docker-compose in a
# Codespace) can no longer resolve or reach it at all — the trade-off
# ADR 0005 flagged as deferred until the app ran inside AKS.
resource "azurerm_private_dns_zone" "postgres" {
  name                = "${var.project_name}.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  name                  = "${var.project_name}-postgres-dns-link"
  private_dns_zone_name = azurerm_private_dns_zone.postgres.name
  virtual_network_id    = azurerm_virtual_network.main.id
  resource_group_name   = azurerm_resource_group.main.name
}

# ============================================================
# NETWORK SECURITY GROUP (NSG)
# ============================================================
# WHY: An NSG is a firewall attached to a subnet. By default Azure allows
# some baseline traffic (like within the VNet); NSGs let you explicitly
# tighten that. Here we start simple: deny all inbound internet traffic to
# the AKS subnet by default (implicit — we just don't add an allow rule for
# it). You'll add a real allow-rule when Nginx/ingress needs to talk to it
# in Stage 3.

resource "azurerm_network_security_group" "aks" {
  name                = "${var.project_name}-aks-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_subnet_network_security_group_association" "aks" {
  subnet_id                 = azurerm_subnet.aks.id
  network_security_group_id = azurerm_network_security_group.aks.id
}

# ============================================================
# ALLOW LOAD-BALANCED TRAFFIC THROUGH TO NODEPORTS
# ============================================================
# WHY this rule is REQUIRED: a Kubernetes Service of type LoadBalancer
# (like the ingress-nginx controller's Service) works by Azure's Load
# Balancer DNAT-ing incoming internet traffic to a NodePort on one of the
# AKS nodes (visible via `kubectl get svc` — e.g. "443:31144/TCP"). That
# forwarded packet still carries the ORIGINAL CLIENT'S source IP when it
# reaches the node's network interface — Azure's Standard Load Balancer
# preserves source IP, it does not masquerade traffic as coming from
# "the load balancer" itself.
#
# The default NSG rule "AllowAzureLoadBalancerInBound" does NOT cover
# this — it only recognizes Azure's own internal health-probe traffic.
# Without an explicit rule here, this custom NSG's default
# "DenyAllInBound" silently drops every real client request, which is
# exactly what caused a connection timeout on both ports 80 and 443 the
# first time the ingress controller was tested (see
# docs/adr/0013-nsg-loadbalancer-nodeport-rule.md for the full story).
#
# This is specifically a consequence of attaching a CUSTOM NSG to the AKS
# subnet — clusters that let AKS fully manage its own networking don't
# need this rule added manually, since AKS's own managed NSG handles it
# automatically.
resource "azurerm_network_security_rule" "allow_loadbalancer_nodeports" {
  name                        = "allow-loadbalancer-nodeports"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "30000-32767"   # the default Kubernetes NodePort range
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.aks.name
}

# ============================================================
# AKS CLUSTER (skeleton — deliberately minimal for now)
# ============================================================
# WHY: This is the compute layer your app will eventually run on. We're
# provisioning it now so Stage 0 gives you a working cluster, but we're NOT
# deploying anything to it yet — that happens once your app exists (Stage 4
# in the plan). Using the smallest viable node size to stay within student
# subscription limits/credits.

resource "azurerm_kubernetes_cluster" "main" {
  name                = "${var.project_name}-${var.environment}-aks"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "${var.project_name}${var.environment}"

  default_node_pool {
    name           = "default"
    node_count     = 1                # keep it to 1 node while learning — scale later
    vm_size        = var.node_vm_size
    vnet_subnet_id = azurerm_subnet.aks.id
  }

  identity {
    type = "SystemAssigned"   # AKS manages its own identity — sets you up for
                               # the managed-identity/Key Vault work in Stage 2
  }

  # WHY set this explicitly: Azure defaults new AKS clusters to OIDC issuer
  # enabled, but that default wasn't declared here originally. Terraform's
  # plan then assumed "should be false" (unset) and tried to DISABLE it on
  # update — which Azure rejects outright once it's on, since it can't be
  # turned back off. Declaring it explicitly keeps Terraform's model of the
  # world matching the real cluster, so no phantom "fix" gets attempted.
  oidc_issuer_enabled = true

  # WHY this is a SEPARATE flag from oidc_issuer_enabled above: the OIDC
  # issuer is the identity-provider mechanism itself; this flag turns on
  # AKS's own Workload Identity admission webhook, which is what actually
  # watches for pods using an annotated ServiceAccount and injects the
  # token exchange machinery into them. Both are required together — the
  # federated credential trust relationship configured earlier does
  # nothing on its own without this webhook running in the cluster.
  workload_identity_enabled = true

  network_profile {
    network_plugin = "azure"  # "azure" CNI gives pods real VNet IPs — the
                               # more production-realistic option vs "kubenet",
                               # worth understanding the tradeoff between them

    # WHY these are set explicitly:
    # With Azure CNI, Kubernetes Services get virtual IPs from a SEPARATE
    # address range than the VNet — they're not real network locations, just
    # internal routing addresses kube-proxy uses. This range must NOT overlap
    # your VNet's address space (10.0.0.0/16), or AKS creation fails with
    # "ServiceCidrOverlapExistingSubnetsCidr". Using 10.100.0.0/16 here since
    # it's well clear of the 10.0.0.0/16 VNet range.
    service_cidr   = "10.100.0.0/16"
    dns_service_ip = "10.100.0.10"   # must be inside service_cidr, conventionally .10
  }

  tags = {
    environment = var.environment
    project     = var.project_name
  }
}

# ============================================================
# POSTGRES ADMIN PASSWORD
# ============================================================
# WHY generate this instead of hardcoding a variable default:
# A hardcoded default password would end up committed to git the moment
# anyone forgets to override it — random_password guarantees a strong,
# unique value that never lives in source control. It DOES live in
# Terraform state, which is why remote state + restricted access to it
# matters in a real team setting (see the note in providers.tf).
#
# NOTE: this password still isn't in Key Vault yet — that's the very next
# step (Stage 2c). For now, retrieve it with:
#   terraform output -raw postgres_admin_password

resource "random_password" "postgres_admin" {
  length  = 24
  special = true
  # WHY this specific set instead of the default special-char set:
  # "#" caused a real bug — .env file parsers treat an unquoted "#" as the
  # start of a comment, silently truncating everything after it. Also
  # excluding characters that are risky when a secret crosses a shell or
  # config-file boundary at all: $ ` ' " ; & | < > and whitespace. 24
  # characters from this set is still a very strong password — dropping a
  # few punctuation options costs negligible entropy.
  override_special = "!%*()-_=+"
}

# ============================================================
# AZURE DATABASE FOR POSTGRESQL — FLEXIBLE SERVER
# ============================================================
# WHY "Flexible Server" specifically: it's Microsoft's current-generation
# managed Postgres offering (the older "Single Server" SKU is deprecated).
# Any Postgres tutorial/docs referencing "Single Server" are out of date.

resource "azurerm_postgresql_flexible_server" "main" {
  name                = "${var.project_name}-${var.environment}-psql"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  version  = var.postgres_version
  sku_name = var.postgres_sku_name

  storage_mb = 32768   # 32GB — minimum allowed, plenty for learning

  administrator_login    = var.postgres_admin_username
  administrator_password = random_password.postgres_admin.result

  # WHY private VNet integration now, after starting public in ADR 0005:
  # the app now runs inside the VNet via AKS, so it no longer needs an
  # internet-routable path to reach Postgres. Disabling public access
  # entirely removes the attack surface a wide-open firewall rule
  # represented — the server now has NO internet-facing endpoint at all.
  public_network_access_enabled = false
  delegated_subnet_id           = azurerm_subnet.postgres.id
  private_dns_zone_id           = azurerm_private_dns_zone.postgres.id

  zone = "1"

  tags = {
    environment = var.environment
    project     = var.project_name
  }

  # WHY this dependency is required, not just good practice: Azure's API
  # rejects Postgres Flexible Server creation with private VNet
  # integration if the DNS zone isn't already linked to the VNet at
  # creation time — Terraform would otherwise sometimes try to create
  # these in parallel, since it doesn't infer this ordering from the
  # attributes alone.
  depends_on = [azurerm_private_dns_zone_virtual_network_link.postgres]
}

resource "azurerm_postgresql_flexible_server_database" "app" {
  name      = var.postgres_db_name
  server_id = azurerm_postgresql_flexible_server.main.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

# ============================================================
# CURRENT USER/PRINCIPAL — needed to grant YOU Key Vault access too
# ============================================================
# WHY: "data" blocks read existing info rather than creating anything.
# This one reads details about whoever is running `terraform apply` (you,
# authenticated via `az login`) — used below to grant your own account
# permission to read/write secrets, separate from the app's own identity.

data "azurerm_client_config" "current" {}

# ============================================================
# RANDOM SUFFIX FOR KEY VAULT NAME
# ============================================================
# WHY: Key Vault names must be GLOBALLY unique across all of Azure (not
# just your subscription) — "cloudbe-dev-kv" is almost certainly already
# taken by someone else's vault. A random suffix avoids that collision.

resource "random_string" "kv_suffix" {
  length  = 4
  special = false
  upper   = false
}

# ============================================================
# KEY VAULT
# ============================================================
resource "azurerm_key_vault" "main" {
  name                = "${var.project_name}${var.environment}kv${random_string.kv_suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  # WHY RBAC over "access policies": Azure RBAC is the current recommended
  # model — permissions are granted the same way as every other Azure
  # resource (role assignments), instead of Key Vault's older, separate
  # access-policy system. Fewer concepts to learn, and it's what current
  # Azure docs push you toward.
  enable_rbac_authorization = true

  purge_protection_enabled = false   # learning project — allows immediate
                                      # full deletion instead of a mandatory
                                      # 90-day soft-delete retention. A real
                                      # production vault would enable this.
}

# ============================================================
# USER-ASSIGNED MANAGED IDENTITY — for the APP specifically
# ============================================================
# WHY separate from AKS's own system-assigned identity (used earlier for
# the cluster itself): that identity represents the CLUSTER's control
# plane. This one represents your APPLICATION's workload — the thing that
# should be allowed to read secrets. Keeping them separate follows least-
# privilege: the cluster's own identity doesn't need Key Vault access.

resource "azurerm_user_assigned_identity" "app" {
  name                = "${var.project_name}-${var.environment}-app-identity"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}

# ============================================================
# ROLE ASSIGNMENTS — who can do what on the vault
# ============================================================

resource "azurerm_role_assignment" "app_identity_secrets_user" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"   # READ-only — the app only needs to fetch, never write
  principal_id         = azurerm_user_assigned_identity.app.principal_id
}

resource "azurerm_role_assignment" "current_user_secrets_officer" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"   # read+write — so YOU can manage secrets via az/terraform
  principal_id         = data.azurerm_client_config.current.object_id
}

# ============================================================
# FEDERATED IDENTITY CREDENTIAL — the actual trust relationship
# ============================================================
# WHY this is the core of Workload Identity: this resource tells Azure AD
# "trust tokens issued by THIS cluster's OIDC issuer, for THIS specific
# Kubernetes ServiceAccount, and let them exchange for a real token as
# THIS managed identity." Nothing works without this exact trust binding.

resource "azurerm_federated_identity_credential" "app_workload_identity" {
  name                = "${var.project_name}-app-federated-credential"
  resource_group_name = azurerm_resource_group.main.name
  parent_id           = azurerm_user_assigned_identity.app.id
  audience            = ["api://AzureADTokenExchange"]   # fixed value required by the workload identity spec
  issuer              = azurerm_kubernetes_cluster.main.oidc_issuer_url
  subject             = "system:serviceaccount:${var.k8s_namespace}:${var.k8s_service_account_name}"
}

# ============================================================
# STORE THE POSTGRES PASSWORD AS A SECRET
# ============================================================
# WHY: this is the actual payoff — the value that used to live only in
# your local .env file now lives in a real, access-controlled secret
# store. Local .env can eventually be deleted entirely.

resource "azurerm_key_vault_secret" "postgres_admin_password" {
  name         = "postgres-admin-password"
  value        = random_password.postgres_admin.result
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_role_assignment.current_user_secrets_officer]
}

# ============================================================
# AZURE CONTAINER REGISTRY (ACR)
# ============================================================
# WHY: AKS can't pull an image that only exists in your local Docker
# build — it needs a registry it can reach. ACR is Azure's managed
# container registry, and (like everything else in this project) we
# authenticate to it via a managed identity role assignment rather than a
# username/password.

resource "azurerm_container_registry" "main" {
  name                = "${var.project_name}${var.environment}acr${random_string.kv_suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"

  # WHY false: admin_enabled would create a static username/password for
  # the registry — exactly the kind of standing credential this project
  # has avoided everywhere else. AKS pulls images using its own identity
  # instead (role assignment below), so no registry password ever exists.
  admin_enabled = false
}

# ============================================================
# GRANT AKS PULL ACCESS — via the KUBELET identity, not the cluster identity
# ============================================================
# WHY kubelet_identity specifically: AKS actually has TWO separate
# identities under the hood. The one set in the `identity {}` block earlier
# (SystemAssigned) represents the CLUSTER'S CONTROL PLANE. A SEPARATE
# identity — the "kubelet identity" — is what the actual NODES use to do
# node-level operations like pulling container images. Granting ACR access
# to the wrong identity is a common real-world mistake that silently fails
# with confusing "ImagePullBackOff" errors — worth knowing this distinction
# exists before you hit that error yourself.

resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}
