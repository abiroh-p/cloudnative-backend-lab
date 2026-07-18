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
  description = "VM size for AKS nodes. Student subscriptions restrict availability by region."
  type        = string
  default     = "Standard_B2s_v2"
}