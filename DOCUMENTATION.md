# Déploiement de Vault sur Kubernetes avec Terraform — Documentation A→Z

> Guide pas-à-pas pensé pour un débutant. Objectif : déployer **HashiCorp Vault**
> sur un cluster **Kubernetes local (kind)** à l'aide de **Terraform**, puis vérifier
> la qualité et la sécurité du code Terraform avec **TFLint** et **Checkov**.

---

## 1. C'est quoi, et pourquoi ?

| Outil | Rôle en une phrase |
|-------|--------------------|
| **Docker** | Fait tourner des conteneurs (des mini-machines isolées). |
| **kind** | *Kubernetes IN Docker* : crée un cluster Kubernetes complet à l'intérieur de Docker, sur ton PC. |
| **kubectl** | La télécommande pour parler à Kubernetes. |
| **Helm** | Le « gestionnaire de paquets » de Kubernetes (installe des applis packagées = *charts*). |
| **Terraform** | Décrit l'infrastructure en fichiers texte (`.tf`) et la crée automatiquement (*Infrastructure as Code*). |
| **Vault** | Coffre-fort à secrets (mots de passe, tokens, certificats). C'est l'appli qu'on déploie. |
| **TFLint** | Vérifie que le code Terraform est propre et sans erreur (*linter*). |
| **Checkov** | Analyse le code Terraform à la recherche de failles de sécurité (*scanner SAST*). |

**L'idée générale :** au lieu de cliquer partout à la main, on **écrit** ce qu'on veut
(« je veux Vault dans un namespace `vault` ») dans des fichiers Terraform, et Terraform
se charge de le créer dans Kubernetes. Ensuite on **scanne** ces fichiers pour s'assurer
qu'ils sont corrects et sûrs avant de les livrer.

---

## 2. Le schéma global (vue d'ensemble)

```
   TON PC (macOS)
   ┌─────────────────────────────────────────────────────────────┐
   │                                                             │
   │   terraform apply                                           │
   │        │                                                    │
   │        │ (1) provider kubernetes  → crée le namespace       │
   │        │ (2) provider helm        → installe le chart Vault │
   │        ▼                                                    │
   │   ┌──────────────── Docker ────────────────┐                │
   │   │   Cluster kind « cluster-devops »       │                │
   │   │                                         │                │
   │   │   Namespace: vault                      │                │
   │   │   ┌───────────────────────────────┐     │                │
   │   │   │  Pod  vault-0  (Vault 1.17.2)  │     │                │
   │   │   │  mode dev, déscellé, token=root│     │                │
   │   │   └───────────────────────────────┘     │                │
   │   │   Service: vault (ClusterIP:8200)        │                │
   │   └─────────────────────────────────────────┘                │
   │                                                             │
   │   Vérification du code :  TFLint  +  Checkov                 │
   └─────────────────────────────────────────────────────────────┘
```

---

## 3. Prérequis (les outils à installer)

Sur macOS, tout passe par **Homebrew** (`brew`). Les versions entre parenthèses sont
celles utilisées dans ce projet.

```bash
# Déjà présents normalement
brew install docker kind kubectl terraform   # (terraform v1.14.7)

# Installés pour ce projet
brew install helm                             # (helm v4.2.1)
brew install checkov                          # (checkov 3.3.0)

# ⚠️ TFLint n'est PAS dans le dépôt Homebrew standard : il faut son "tap" officiel
brew install terraform-linters/tap/tflint     # (tflint 0.63.1)
```

> 💡 **Piège rencontré :** `brew install tflint` ne marche pas (Homebrew propose un
> paquet sans rapport nommé « tint »). Il **faut** utiliser `terraform-linters/tap/tflint`.

Vérifier que tout répond :

```bash
docker --version
kind --version
kubectl version --client
terraform version
helm version --short
tflint --version
checkov --version
```

---

## 4. Préparer le cluster Kubernetes local (kind)

Si tu n'as pas encore de cluster :

```bash
kind create cluster --name cluster-devops
```

Cela crée un conteneur Docker `cluster-devops-control-plane` qui héberge Kubernetes,
et ajoute automatiquement un *contexte* kubectl nommé **`kind-cluster-devops`**.

Vérifier qu'il répond :

```bash
kubectl --context kind-cluster-devops get nodes
```

> 💡 **Piège rencontré :** juste après un (re)démarrage du conteneur, l'API de
> Kubernetes met quelques secondes à être prête. Pendant ce court instant, `kubectl`
> peut renvoyer une erreur `Forbidden`. Il suffit d'**attendre ~5-10 s** et de réessayer.

---

## 5. Le code Terraform (dossier `terraform/`)

Le code est découpé en plusieurs fichiers, c'est la bonne pratique (un fichier = un rôle).

### `terraform/versions.tf` — quelles versions d'outils on exige
```hcl
terraform {
  required_version = ">= 1.5"
  required_providers {
    helm       = { source = "hashicorp/helm",       version = "~> 3.0" }
    kubernetes = { source = "hashicorp/kubernetes",  version = "~> 2.31" }
  }
}
```
Les *providers* sont les « plugins » qui permettent à Terraform de parler à Helm et à Kubernetes.

### `terraform/providers.tf` — comment se connecter au cluster
```hcl
provider "kubernetes" {
  config_path    = var.kubeconfig_path   # ~/.kube/config
  config_context = var.kube_context      # kind-cluster-devops
}

provider "helm" {
  kubernetes = {                         # ⚠️ syntaxe Helm provider v3 : "=" (attribut)
    config_path    = var.kubeconfig_path
    config_context = var.kube_context
  }
}
```

> 💡 **Piège rencontré (important) :** le **provider Helm v3** a changé de syntaxe par
> rapport au v2. Le bloc `kubernetes { ... }` devient un **attribut** `kubernetes = { ... }`,
> et plus loin les blocs `set { ... }` deviennent une **liste** `set = [ {…}, {…} ]`.
> Si tu copies un vieux tuto (syntaxe v2), tu auras l'erreur
> *« Blocks of type "set"/"kubernetes" are not expected here »*.

### `terraform/variables.tf` — les paramètres réglables
Définit `kubeconfig_path`, `kube_context`, `vault_namespace`, `vault_chart_version`,
et `vault_dev_root_token` (marqué `sensitive` pour ne pas l'afficher dans les logs).

### `terraform/main.tf` — ce qu'on déploie réellement
```hcl
# 1) On crée le namespace "vault"
resource "kubernetes_namespace" "vault" {
  metadata {
    name   = var.vault_namespace
    labels = { "app.kubernetes.io/managed-by" = "terraform" }
  }
}

# 2) On installe Vault via son chart Helm officiel, en mode "dev"
resource "helm_release" "vault" {
  name       = "vault"
  repository = "https://helm.releases.hashicorp.com"
  chart      = "vault"
  version    = var.vault_chart_version
  namespace  = kubernetes_namespace.vault.metadata[0].name

  set = [
    { name = "server.dev.enabled",      value = "true" },               # mode dev
    { name = "server.dev.devRootToken", value = var.vault_dev_root_token }, # token = root
    { name = "injector.enabled",        value = "false" },              # on simplifie
  ]
}
```

**Mode dev :** un seul pod, stockage **en mémoire**, Vault est **déscellé**
(*unsealed*) automatiquement et le token root est fixé. Parfait pour apprendre/tester.
⚠️ **À ne jamais utiliser en production** : tout est perdu au redémarrage et le token est trivial.

### `terraform/outputs.tf` — ce que Terraform affiche à la fin
Le namespace, le statut du déploiement, et la commande toute prête pour ouvrir l'UI.

### `terraform/.tflint.hcl` — configuration de TFLint
Active le jeu de règles « recommended » pour Terraform.

---

## 6. Dérouler le déploiement (les commandes, dans l'ordre)

Toutes les commandes se lancent **depuis le dossier `terraform/`** :

```bash
cd terraform
```

### Étape 1 — Initialiser (télécharge les providers)
```bash
terraform init
```

### Étape 2 — Mettre en forme + valider la syntaxe
```bash
terraform fmt        # aligne/indente proprement les fichiers
terraform validate   # → "Success! The configuration is valid."
```

### Étape 3 — Vérifier le code avec TFLint
```bash
tflint --init        # télécharge le plugin de règles Terraform (1 seule fois)
tflint               # aucune sortie + code de retour 0 = aucun problème ✅
```

### Étape 4 — Scanner la sécurité avec Checkov
```bash
checkov -d .
```

> 💡 **Résultat attendu ici : Checkov ne remonte AUCUN résultat (ni passé, ni échoué).**
> Ce n'est **pas un bug**. Checkov ne « compte » une ressource que s'il possède au moins
> une règle de sécurité pour son type. Or il n'embarque **aucune politique** pour
> `helm_release` ni `kubernetes_namespace`. Donc il scanne, ne trouve rien à vérifier,
> et affiche un résumé vide. (Test de contrôle : sur un `aws_s3_bucket`, Checkov affiche
> bien « Passed checks: 1 » — la preuve qu'il fonctionne.)

### Étape 5 — Prévisualiser puis appliquer
```bash
terraform plan       # montre ce qui VA être créé (ici : 2 ressources à ajouter)
terraform apply -auto-approve   # crée réellement le namespace + installe Vault
```

Sortie attendue :
```
kubernetes_namespace.vault: Creation complete after 0s [id=vault]
helm_release.vault:        Creation complete after 4s [id=vault]
Apply complete! Resources: 2 added, 0 changed, 0 destroyed.
```

---

## 7. Vérifier que Vault tourne bien

```bash
# Le pod doit être Running et 1/1
kubectl -n vault get pods

# Attendre qu'il soit prêt
kubectl -n vault wait --for=condition=Ready pod/vault-0 --timeout=60s

# Statut interne de Vault
kubectl -n vault exec vault-0 -- vault status
```

Résultat constaté :
```
Initialized   true
Sealed        false        ← coffre OUVERT (déscellé), prêt à l'emploi
Storage Type  inmem        ← stockage en mémoire (mode dev)
Version       1.17.2
```

---

## 8. Accéder à l'interface web de Vault

Le service Vault est en `ClusterIP` : il n'est **pas** exposé directement hors du cluster.
On crée un tunnel temporaire avec `port-forward` :

```bash
kubectl -n vault port-forward svc/vault 8200:8200
```

Puis dans le navigateur :

```
http://127.0.0.1:8200
```

Se connecter avec la méthode **Token** et la valeur **`root`**.

> ⚠️ On utilise toujours **`127.0.0.1` (localhost)**, jamais l'IP interne du conteneur/pod.
> (C'est l'erreur classique du tout début : viser `172.x.x.x` ne marche pas depuis le PC.)

---

## 9. Nettoyer / tout supprimer

```bash
cd terraform
terraform destroy -auto-approve     # supprime Vault + le namespace

# (optionnel) supprimer tout le cluster
kind delete cluster --name cluster-devops
```

---

## 10. Lien avec la CI GitHub Actions

Le fichier `.github/workflows/CI.yaml` rejoue ces mêmes étapes automatiquement à chaque
`push`/`pull_request` sur `main` : il démarre Vault, puis lance `terraform init/plan`.
L'idée est d'y ajouter aussi les étapes **`tflint`** et **`checkov`** pour bloquer toute
livraison de code Terraform non conforme. *(Le workflow actuel contient encore quelques
erreurs de syntaxe à corriger — voir note plus bas.)*

---

## 11. Récapitulatif des pièges rencontrés (mémo)

| Symptôme | Cause | Solution |
|----------|-------|----------|
| Vault inaccessible sur `172.x.x.x:8200` | IP interne + port non publié | Utiliser `127.0.0.1` + `-p 8200:8200` |
| `brew install tflint` propose « tint » | TFLint absent du dépôt standard | `brew install terraform-linters/tap/tflint` |
| `Blocks of type "set" are not expected here` | Syntaxe Helm provider **v2** sur un provider **v3** | Utiliser `set = [ {…} ]` et `kubernetes = {…}` |
| `kubectl … Forbidden` juste après démarrage | API Kubernetes pas encore prête | Attendre ~10 s et réessayer |
| Checkov n'affiche aucun résultat | Aucune règle pour `helm_release`/`kubernetes_namespace` | Comportement normal, pas une erreur |

---

## 12. Antisèche (toutes les commandes, condensé)

```bash
# --- Installation ---
brew install helm checkov
brew install terraform-linters/tap/tflint

# --- Cluster ---
kind create cluster --name cluster-devops

# --- Déploiement + vérifications ---
cd terraform
terraform init
terraform fmt && terraform validate
tflint --init && tflint
checkov -d .
terraform plan
terraform apply -auto-approve

# --- Vérifier Vault ---
kubectl -n vault get pods
kubectl -n vault exec vault-0 -- vault status

# --- Accès UI ---
kubectl -n vault port-forward svc/vault 8200:8200   # → http://127.0.0.1:8200 (token: root)

# --- Nettoyage ---
terraform destroy -auto-approve
```
