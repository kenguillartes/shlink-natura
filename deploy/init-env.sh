#!/bin/sh
# Generate /opt/shlink-natura/.env from deploy/natura.env + random secrets.
# Idempotent: refuses to overwrite an existing .env unless called with --force.
set -e

DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$DIR/.env"

if [ -f "$ENV_FILE" ] && [ "$1" != "--force" ]; then
    echo ".env already exists — not touching it (use --force to regenerate)."
    exit 0
fi

API_KEY="$(openssl rand -hex 24)"

cp "$DIR/deploy/natura.env" "$ENV_FILE"
{
    echo ""
    echo "# --- generated secrets ($(date -u +%Y-%m-%dT%H:%M:%SZ)) ---"
    echo "DB_PASSWORD=$(openssl rand -hex 24)"
    echo "DB_ROOT_PASSWORD=$(openssl rand -hex 24)"
    echo "SHLINK_API_KEY=$API_KEY"
    echo "INITIAL_API_KEY=$API_KEY"
} >> "$ENV_FILE"
chmod 600 "$ENV_FILE"

echo ".env written to $ENV_FILE"
echo "Still needed before the Odoo sync works: ODOO_DB and ODOO_API_KEY (edit $ENV_FILE)."
