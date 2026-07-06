#!/bin/sh
# Add or update a web-UI login. Usage: sh deploy/set-webui-password.sh <username>
# Prompts for the password (openssl), writes deploy/htpasswd (not committed to git).
set -e
cd "$(dirname "$0")"

USER_NAME="${1:?usage: sh deploy/set-webui-password.sh <username>}"

echo "Setting web UI password for user: $USER_NAME"
HASH="$(openssl passwd -apr1)"

grep -v "^$USER_NAME:" htpasswd 2>/dev/null > htpasswd.tmp || true
echo "$USER_NAME:$HASH" >> htpasswd.tmp
mv htpasswd.tmp htpasswd
chmod 644 htpasswd

echo "Saved. Apply with: make up"
