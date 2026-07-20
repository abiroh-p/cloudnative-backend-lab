# WHY this file exists:
# Hardcoding values like region or project name directly into resources means
# you have to hunt through every file to change them later. Variables
# centralize the "knobs" of your infrastructure in one place.

variable "project_name" {
  description = "Short name used as a prefix for all resources (industry convention: lowercase, no spaces)"
  type        = string
  default     = "cloudbe"
}

variable "environment" {
  description = "Deployment environment — lets the same code provision dev/staging/prod with different values"
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Azure region. Pick one close to you for lower latency during testing."
  type        = string
  default     = "centralindia"   # closest region to Siliguri, IN — change if you prefer another
}

variable "vnet_address_space" {
  description = "CIDR block for the whole virtual network"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "aks_subnet_address_prefix" {
  description = "CIDR block for the subnet AKS nodes will live in"
  type        = list(string)
  default     = ["10.0.1.0/24"]
}

variable "public_subnet_address_prefix" {
  description = "CIDR block for the public-facing subnet (Nginx/ingress will live here in a later stage)"
  type        = list(string)
  default     = ["10.0.2.0/24"]
}

variable "node_vm_size" {
  description = <<-EOT
    VM size for AKS nodes. NOTE: not every VM size is available in every
    region/subscription — student subscriptions in particular restrict this
    list. If you hit a "VM size not allowed" error, run:
      az vm list-skus --location <region> --size Standard_B2 --output table
    to see what's actually available to you, and override this variable.
  EOT
  type        = string
  default     = "Standard_B2s_v2"   # burstable, 2 vCPU / 4GB — cheapest general-purpose option
}

variable "postgres_admin_username" {
  description = "Admin username for the Postgres server. NOTE: Azure disallows certain reserved names (postgres, admin, root, azure_superuser, etc.)."
  type        = string
  default     = "pgadmin"
}

variable "postgres_sku_name" {
  description = <<-EOT
    Compute tier for the Postgres Flexible Server. B_Standard_B1ms is the
    cheapest burstable tier — same "check what your subscription actually
    allows" caveat as node_vm_size applies here too. If this gets rejected:
      az postgres flexible-server list-skus --location <region> --output table
  EOT
  type        = string
  default     = "B_Standard_B1ms"
}

variable "postgres_version" {
  description = "Postgres major version"
  type        = string
  default     = "16"
}

variable "postgres_db_name" {
  description = "Name of the application database (must match app's POSTGRES_DB setting)"
  type        = string
  default     = "appdb"
}

variable "postgres_subnet_address_prefix" {
  description = "CIDR block for the delegated subnet Postgres Flexible Server uses for private VNet integration"
  type        = list(string)
  default     = ["10.0.3.0/24"]
}

variable "k8s_namespace" {
  description = "Kubernetes namespace the app's ServiceAccount will live in (created for real in Stage 4 — this just pre-registers the trust relationship)"
  type        = string
  default     = "default"
}

variable "k8s_service_account_name" {
  description = "Name of the Kubernetes ServiceAccount the app will use (created for real in Stage 4)"
  type        = string
  default     = "backend-app"
}
