# WHY this file exists:
# After "terraform apply", Terraform's default output is noisy. Outputs let
# you surface just the values you actually need next (like the command to
# connect kubectl to your new cluster).

output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "aks_cluster_name" {
  value = azurerm_kubernetes_cluster.main.name
}

output "get_credentials_command" {
  description = "Run this after apply to point kubectl at your new cluster"
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.main.name} --name ${azurerm_kubernetes_cluster.main.name}"
}

output "vnet_id" {
  value = azurerm_virtual_network.main.id
}

output "postgres_fqdn" {
  description = "Fully qualified hostname of the Postgres server — use this as POSTGRES_HOST"
  value       = azurerm_postgresql_flexible_server.main.fqdn
}

output "postgres_admin_username" {
  value = var.postgres_admin_username
}

output "postgres_admin_password" {
  description = "Retrieve with: terraform output -raw postgres_admin_password"
  value       = random_password.postgres_admin.result
  sensitive   = true
}

output "postgres_db_name" {
  value = var.postgres_db_name
}

output "key_vault_uri" {
  description = "Use this as KEY_VAULT_URI in the app's config"
  value       = azurerm_key_vault.main.vault_uri
}

output "key_vault_name" {
  value = azurerm_key_vault.main.name
}

output "app_identity_client_id" {
  description = "Used later (Stage 4) to annotate the Kubernetes ServiceAccount for Workload Identity"
  value       = azurerm_user_assigned_identity.app.client_id
}
