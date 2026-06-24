# Clé SSH déposée dans le projet Hetzner pour l'accès au serveur.
resource "hcloud_ssh_key" "default" {
  name       = "${var.server_name}-key"
  public_key = var.ssh_public_key
}

# Pare-feu : SSH restreint, HTTP/HTTPS ouverts (HTTP nécessaire pour Let's Encrypt + redirection).
resource "hcloud_firewall" "harbor" {
  name = "${var.server_name}-fw"

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = var.ssh_allowed_ips
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "80"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "443"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
}

# Serveur Harbor. L'installation se fait au premier boot via cloud-init :
#  - le fichier /etc/harbor.env porte les valeurs (domaine, email, mot de passe admin, version)
#  - le script /opt/harbor-bootstrap.sh installe Docker, récupère le certificat TLS et lance Harbor
#  - un service systemd oneshot exécute le script et le relance en cas d'échec (ex. DNS pas encore propagé)
resource "hcloud_server" "harbor" {
  name         = var.server_name
  image        = var.os_image
  server_type  = var.server_type
  location     = var.location
  ssh_keys     = [hcloud_ssh_key.default.id]
  firewall_ids = [hcloud_firewall.harbor.id]

  user_data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    harbor_env_b64 = base64encode(templatefile("${path.module}/harbor.env.tftpl", {
      domain                = var.domain
      letsencrypt_email     = var.letsencrypt_email
      harbor_admin_password = var.harbor_admin_password
      harbor_version        = var.harbor_version
    }))
    bootstrap_b64 = base64encode(file("${path.module}/harbor-bootstrap.sh"))
  })

  labels = {
    app          = "harbor"
    "managed-by" = "terraform"
  }
}
