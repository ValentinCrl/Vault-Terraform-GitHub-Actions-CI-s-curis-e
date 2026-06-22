# Image nginx déjà durcie : tourne en non-root (uid 101) et écoute sur 8080
FROM nginxinc/nginx-unprivileged:1.27-alpine

# Métadonnées
LABEL org.opencontainers.image.title="Moteur de recherche" \
      org.opencontainers.image.description="Application statique servie par nginx (non-root)" \
      org.opencontainers.image.licenses="MIT"

# Configuration nginx durcie
COPY nginx.conf /etc/nginx/nginx.conf

# Contenu statique de l'application
COPY recherche.html /usr/share/nginx/html/index.html

# Port non privilégié
EXPOSE 8080

# Vérification de l'état du conteneur
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget -qO- http://127.0.0.1:8080/healthz || exit 1
