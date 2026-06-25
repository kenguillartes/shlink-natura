#!/bin/sh
# Generates a self-signed TLS certificate for local/private use.
# For a public domain, replace cert.pem and key.pem with certs from
# Certbot (Let's Encrypt) or your DNS provider.
set -e

SSL_DIR="$(dirname "$0")/nginx/ssl"
CERT="$SSL_DIR/cert.pem"
KEY="$SSL_DIR/key.pem"

# Skip if certs already exist
if [ -f "$CERT" ] && [ -f "$KEY" ]; then
    echo "==> SSL certs already exist, skipping generation."
    exit 0
fi

mkdir -p "$SSL_DIR"

echo "==> Generating self-signed certificate (10 year validity)..."
openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
    -keyout "$KEY" \
    -out "$CERT" \
    -subj "/C=US/ST=Local/L=Local/O=ShlinkNatura/CN=shlink-natura" \
    2>/dev/null

chmod 600 "$KEY"
echo "==> Certificate generated at $SSL_DIR"
echo "    Replace cert.pem and key.pem with real certs for a public domain."
