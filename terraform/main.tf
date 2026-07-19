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

  # See docs/adr/0005 — public access is a deliberate, temporary choice
  # for this stage. Once the app runs inside AKS (same VNet) in Stage 4,
  # this moves to private VNet integration instead.
  public_network_access_enabled = true

  zone = "1"

  tags = {
    environment = var.environment
    project     = var.project_name
  }
}

resource "azurerm_postgresql_flexible_server_database" "app" {
  name      = var.postgres_db_name
  server_id = azurerm_postgresql_flexible_server.main.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

# ============================================================
# FIREWALL RULE
# ============================================================
# WHY this is wide open by default: see docs/adr/0005 — this is a
# temporary, learning-stage trade-off, not a production pattern. A real
# deployment either uses VNet integration (no public exposure at all) or a
# tightly scoped firewall rule for known static IPs (e.g. a CI runner).

resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_learning_access" {
  name             = "allow-learning-access"
  server_id        = azurerm_postgresql_flexible_server.main.id
  start_ip_address = var.postgres_allowed_ip_start
  end_ip_address   = var.postgres_allowed_ip_end
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
