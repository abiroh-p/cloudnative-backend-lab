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

  network_profile {
    network_plugin = "azure"
    service_cidr    = "10.100.0.0/16"
    dns_service_ip  = "10.100.0.10"
  }

  default_node_pool {
    name           = "default"
    node_count     = 1                
    vm_size = var.node_vm_size
    vnet_subnet_id = azurerm_subnet.aks.id
  }

  identity {
    type = "SystemAssigned"   # AKS manages its own identity — sets you up for
                               # the managed-identity/Key Vault work in Stage 2
  }

  tags = {
    environment = var.environment
    project     = var.project_name
  }
}
