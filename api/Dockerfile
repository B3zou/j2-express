# ─────────────────────────────────────────────────────────────────────────────
# Image de DÉVELOPPEMENT de l'API : Node.js 22 (LTS) sur Alpine.
# Le code n'est pas copié dans l'image : ./api est monté sur /app (compose.yaml),
# et node_modules est installé dans ce dossier partagé au premier démarrage
# (docker-entrypoint.sh), pour que votre éditeur voie les types des bibliothèques.
# ─────────────────────────────────────────────────────────────────────────────
FROM node:22-alpine

WORKDIR /app

# wget sert au healthcheck ; HOME et le cache npm dans /tmp : le conteneur tourne
# avec VOTRE identifiant utilisateur (compose.yaml), qui n'a pas de dossier personnel ici.
ENV HOME=/tmp \
    npm_config_cache=/tmp/npm-cache \
    npm_config_update_notifier=false \
    NODE_ENV=development

COPY --chmod=755 docker-entrypoint.sh /usr/local/bin/docker-entrypoint

EXPOSE 3000
ENTRYPOINT ["docker-entrypoint"]
CMD ["npm", "run", "dev"]
