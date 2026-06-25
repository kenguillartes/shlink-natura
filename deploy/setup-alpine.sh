#!/bin/sh
# =================================================================
# Shlink Natura — One-time VM bootstrap for Alpine Linux (Proxmox)
# Run as root on a fresh Alpine Linux install
# =================================================================
set -e

REPO_URL="https://github.com/kenguillartes/shlink-natura.git"
DEPLOY_DIR="/opt/shlink-natura"
DEPLOY_USER="shlink"

echo "==> Updating packages..."
apk update && apk upgrade

echo "==> Installing Docker, Git, Make, and OpenSSL..."
apk add docker docker-cli-compose git make openssl

echo "==> Enabling Docker service on boot..."
rc-update add docker boot
service docker start

echo "==> Creating deploy user: ${DEPLOY_USER}..."
adduser -D -s /bin/sh "${DEPLOY_USER}" || echo "User ${DEPLOY_USER} already exists, skipping."
addgroup "${DEPLOY_USER}" docker

echo "==> Cloning repository to ${DEPLOY_DIR}..."
git clone "${REPO_URL}" "${DEPLOY_DIR}"
chown -R "${DEPLOY_USER}:${DEPLOY_USER}" "${DEPLOY_DIR}"

echo "==> Creating .env from template..."
cp "${DEPLOY_DIR}/.env.example" "${DEPLOY_DIR}/.env"
chmod 600 "${DEPLOY_DIR}/.env"
chown "${DEPLOY_USER}:${DEPLOY_USER}" "${DEPLOY_DIR}/.env"

echo ""
echo "================================================================="
echo " Bootstrap complete!"
echo "================================================================="
echo ""
echo " Next steps — switch to the deploy user:"
echo ""
echo "   su - ${DEPLOY_USER}"
echo "   cd ${DEPLOY_DIR}"
echo ""
echo " Edit .env (set DEFAULT_DOMAIN, DB_PASSWORD, DB_ROOT_PASSWORD):"
echo ""
echo "   vi .env"
echo ""
echo " --- Option A: HTTP only (simplest, good for LAN) ---"
echo ""
echo "   make build && make up"
echo "   # Access at http://<VM-IP>:8080"
echo ""
echo " --- Option B: HTTPS with Nginx reverse proxy ---"
echo ""
echo "   make build && make up-proxy"
echo "   # Access at https://<VM-IP>"
echo "   # Self-signed cert is generated automatically."
echo "   # Replace deploy/nginx/ssl/cert.pem + key.pem with real certs"
echo "   # if you have a public domain."
echo ""
echo " --- Common commands after deploy ---"
echo ""
echo "   make ps          # Check container status"
echo "   make logs        # Tail all logs"
echo "   make logs-shlink # Tail Shlink only"
echo "   make api-key     # Generate a new API key"
echo "   make backup      # Dump the database"
echo "   make update      # Pull latest code and rebuild"
echo "   make restart     # Restart Shlink container only"
echo "================================================================="
