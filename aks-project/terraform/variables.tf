variable "rg_name" {
  description = "Nombre del resource group"
  type        = string
  default     = "rg-aks-project-test"
}

variable "cluster_name" {
  description = "Nombre del clúster AKS"
  type        = string
  default     = "aks-cluster-project-test"
}

variable "dns_prefix" {
  description = "Prefijo DNS del clúster"
  type        = string
  default     = "aksproject"
}

variable "node_count" {
  description = "Número de nodos"
  type        = number
  default     = 1
}

variable "vm_size" {
  description = "Tamaño de VM para los nodos"
  type        = string
  default     = "Standard_D2s_v7"
}

variable "admin_username" {
  description = "Usuario administrador de los nodos"
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key_path" {
  description = "Ruta a la llave pública SSH"
  type        = string
  default     = "~/.ssh/aks_project_key.pub"
}