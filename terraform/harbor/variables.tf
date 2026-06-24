variable "hcloud_token" {
  description = "Token API Hetzner Cloud (Read & Write). À fournir via tfvars ou TF_VAR_hcloud_token."
  type        = string
  sensitive   = true
}

variable "ssh_public_key" {
  description = "Clé SSH publique autorisée à se connecter au serveur (contenu de ~/.ssh/id_ed25519.pub)."
  type        = string
}

variable "ssh_allowed_ips" {
  description = "Adresses autorisées à se connecter en SSH (port 22). Idéalement ton IP/32 plutôt que tout Internet."
  type        = list(string)
  default     = ["0.0.0.0/0", "::/0"]
}

variable "domain" {
  description = "Nom de domaine complet de Harbor (ex. harbor.mondomaine.fr). À faire pointer en DNS vers l'IP du serveur."
  type        = string
}

variable "letsencrypt_email" {
  description = "Email utilisé pour l'enregistrement Let's Encrypt (notifications d'expiration)."
  type        = string
}

variable "harbor_admin_password" {
  description = "Mot de passe du compte admin Harbor (UI). À changer après la première connexion."
  type        = string
  sensitive   = true
}

variable "harbor_version" {
  description = "Version de Harbor à installer (tag de release goharbor/harbor)."
  type        = string
  default     = "v2.13.0"
}

variable "server_name" {
  description = "Nom du serveur Hetzner et préfixe des ressources associées."
  type        = string
  default     = "harbor"
}

variable "server_type" {
  description = "Type de serveur Hetzner. cpx21 = 3 vCPU / 4 Go (minimum confortable pour Harbor)."
  type        = string
  default     = "cx23"
}

variable "location" {
  description = "Datacenter Hetzner (nbg1 = Nuremberg, fsn1 = Falkenstein, hel1 = Helsinki)."
  type        = string
  default     = "nbg1"
}

variable "os_image" {
  description = "Image système du serveur."
  type        = string
  default     = "ubuntu-24.04"
}
