#!/usr/bin/env bash
# Installe Harbor sur le serveur : Docker + certificat Let's Encrypt + Harbor (docker-compose).
# Idempotent : peut être relancé sans tout réinstaller. Lu par le service systemd harbor-bootstrap.
set -euo pipefail

# Valeurs injectées par Terraform (aussi fournies par EnvironmentFile dans le service systemd).
[ -f /etc/harbor.env ] && . /etc/harbor.env

export DEBIAN_FRONTEND=noninteractive

echo "[harbor-bootstrap] $(date -Is) Installation des dépendances..."
apt-get update -y
apt-get install -y ca-certificates curl certbot

# --- Docker ---------------------------------------------------------------
if ! command -v docker >/dev/null 2>&1; then
  echo "[harbor-bootstrap] Installation de Docker..."
  curl -fsSL https://get.docker.com | sh
fi
systemctl enable --now docker

# --- Certificat TLS Let's Encrypt -----------------------------------------
# certbot --standalone écoute sur le port 80. Tant que le DNS de $DOMAIN ne
# pointe pas encore vers ce serveur, l'émission échoue : on réessaie en boucle.
# Les hooks pre/post (arrêt/relance du proxy Harbor) sont enregistrés pour le
# renouvellement automatique ; au premier passage Harbor n'existe pas encore
# (|| true) et le port 80 est donc libre.
echo "[harbor-bootstrap] Obtention du certificat Let's Encrypt pour ${DOMAIN}..."
# --disable-hook-validation : les hooks commencent par `cd` (builtin shell absent
# du PATH), que certbot refuserait sinon de valider.
until certbot certonly --standalone --non-interactive --agree-tos \
        --disable-hook-validation \
        -m "${LETSENCRYPT_EMAIL}" -d "${DOMAIN}" \
        --pre-hook  "cd /opt/harbor && docker compose stop proxy || true" \
        --post-hook "cd /opt/harbor && docker compose start proxy || true"; do
  echo "[harbor-bootstrap] Échec certbot (DNS pas propagé OU autre erreur — voir au-dessus). Nouvelle tentative dans 60s."
  sleep 60
done

# --- Téléchargement de Harbor ---------------------------------------------
if [ ! -x /opt/harbor/install.sh ]; then
  echo "[harbor-bootstrap] Téléchargement de Harbor ${HARBOR_VERSION}..."
  curl -fsSL -o /opt/harbor.tgz \
    "https://github.com/goharbor/harbor/releases/download/${HARBOR_VERSION}/harbor-online-installer-${HARBOR_VERSION}.tgz"
  tar -xzf /opt/harbor.tgz -C /opt
fi

# --- Configuration de harbor.yml ------------------------------------------
cd /opt/harbor
cp -n harbor.yml.tmpl harbor.yml
sed -i "s|^hostname:.*|hostname: ${DOMAIN}|"                             harbor.yml
sed -i "s|^harbor_admin_password:.*|harbor_admin_password: ${HARBOR_ADMIN_PASSWORD}|" harbor.yml
sed -i "s|/your/certificate/path|/etc/letsencrypt/live/${DOMAIN}/fullchain.pem|"      harbor.yml
sed -i "s|/your/private/key/path|/etc/letsencrypt/live/${DOMAIN}/privkey.pem|"        harbor.yml

# --- Installation ----------------------------------------------------------
echo "[harbor-bootstrap] Installation de Harbor..."
./install.sh

echo "[harbor-bootstrap] $(date -Is) Terminé. UI disponible sur https://${DOMAIN}"
