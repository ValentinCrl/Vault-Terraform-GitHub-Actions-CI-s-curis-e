output "vault_namespace" {
  description = "Namespace où Vault est déployé"
  value       = kubernetes_namespace.vault.metadata[0].name
}

output "vault_release_status" {
  description = "Statut du release Helm Vault"
  value       = helm_release.vault.status
}

output "vault_port_forward_cmd" {
  description = "Commande pour exposer l'UI Vault sur http://127.0.0.1:8200"
  value       = "kubectl -n ${kubernetes_namespace.vault.metadata[0].name} port-forward svc/vault 8200:8200"
}
