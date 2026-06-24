# Le token API Hetzner est fourni via la variable hcloud_token.
# Ne jamais le coder en dur : passe-le par terraform.tfvars (gitignored)
# ou par la variable d'environnement TF_VAR_hcloud_token.
provider "hcloud" {
  token = var.hcloud_token
}
