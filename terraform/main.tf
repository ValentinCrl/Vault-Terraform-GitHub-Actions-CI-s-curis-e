resource "kubernetes_namespace" "vault" {
  metadata {
    name = var.vault_namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

resource "helm_release" "vault" {
  name       = "vault"
  repository = "https://helm.releases.hashicorp.com"
  chart      = "vault"
  version    = var.vault_chart_version
  namespace  = kubernetes_namespace.vault.metadata[0].name

  # Vault en mode dev : 1 pod, stockage en mémoire, déscellé automatiquement.
  # injector désactivé (agent sidecar) pour rester minimal en local.
  set = [
    {
      name  = "server.dev.enabled"
      value = "true"
    },
    {
      name  = "server.dev.devRootToken"
      value = var.vault_dev_root_token
    },
    {
      name  = "injector.enabled"
      value = "false"
    },
  ]
}
