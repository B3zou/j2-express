#!/bin/sh
# Installe les dépendances (npm ci) si node_modules manque ou si package-lock.json a changé,
# puis lance la commande demandée (npm run dev par défaut).
set -e

if [ "${INSTALL_DEPS:-1}" != "0" ]; then
  if [ ! -f node_modules/.package-lock.json ] || [ package-lock.json -nt node_modules/.package-lock.json ]; then
    echo "→ npm ci (installation des dépendances, une fois)"
    npm ci --no-audit --no-fund
  fi
fi

exec "$@"
