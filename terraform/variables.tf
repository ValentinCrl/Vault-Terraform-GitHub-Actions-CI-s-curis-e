variable "kubeconfig_path" {
  description = "Chemin vers le fichier kubeconfig"
  type        = string
  default     = "~/.kube/config"
}

variable "kube_context" {
  description = "Contexte Kubernetes ciblé (cluster kind local)"
  type        = string
  default     = "kind-cluster-devops"
}

variable "vault_namespace" {
  description = "Namespace dans lequel déployer Vault"
  type        = string
  default     = "vault"
}

variable "vault_chart_version" {
  description = "Version du chart Helm hashicorp/vault"
  type        = string
  default     = "0.28.1"
}

variable "vault_dev_root_token" {
  description = "Token root utilisé en mode dev (NE PAS utiliser en production)"
  type        = string
  default     = "root"
  sensitive   = true
}
