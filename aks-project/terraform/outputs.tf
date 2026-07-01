output "cluster_name" {
  description = "Nombre del clúster AKS"
  value       = azurerm_kubernetes_cluster.aks.name
}

output "resource_group" {
  description = "Resource group del clúster"
  value       = azurerm_kubernetes_cluster.aks.resource_group_name
}

output "location" {
  description = "Región donde se desplegó el clúster"
  value       = azurerm_kubernetes_cluster.aks.location
}