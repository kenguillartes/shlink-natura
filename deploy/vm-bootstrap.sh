#!/bin/sh
# One-shot bootstrap for the Natura Shlink VM (Alpine, Proxmox VM 113).
# Fetch and run on a fresh install (as root):
#   wget raw.githubusercontent.com/kenguillartes/shlink-natura/feat/qr-asset-tags/deploy/vm-bootstrap.sh
#   sh vm-bootstrap.sh
set -e

BRANCH="feat/qr-asset-tags"
REPO_URL="https://github.com/kenguillartes/shlink-natura.git"
DEPLOY_DIR="/opt/shlink-natura"

echo "==> Installing Docker, Git, Make, OpenSSL..."
apk add docker docker-cli-compose git make openssl

echo "==> Enabling and starting Docker..."
rc-update add docker boot || true
service docker start || true
i=0
until docker info > /dev/null 2>&1; do
    i=$((i + 1))
    [ "$i" -gt 30 ] && echo "Docker daemon did not start" && exit 1
    sleep 2
done

if [ ! -d "$DEPLOY_DIR" ]; then
    echo "==> Cloning $BRANCH to $DEPLOY_DIR..."
    git clone -b "$BRANCH" "$REPO_URL" "$DEPLOY_DIR"
fi

echo "==> Generating .env..."
sh "$DEPLOY_DIR/deploy/init-env.sh"

echo "==> Building and starting the stack (this takes a while)..."
cd "$DEPLOY_DIR"
make build
make up

echo ""
echo "==> Done. Containers:"
docker compose -f docker-compose.prod.yml ps
