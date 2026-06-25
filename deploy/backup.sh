#!/bin/sh
# Dumps the Shlink MariaDB database to ./backups/
# Safe to run while containers are live.
# Keeps the last 7 backups and removes older ones.
set -e

BACKUP_DIR="$(dirname "$0")/../backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
FILENAME="shlink_db_${TIMESTAMP}.sql.gz"

mkdir -p "$BACKUP_DIR"

echo "==> Backing up database..."
docker exec shlink_db sh -c \
    'mariadb-dump -uroot -p"$MARIADB_ROOT_PASSWORD" "$MARIADB_DATABASE"' \
    | gzip > "${BACKUP_DIR}/${FILENAME}"

echo "==> Saved: ${BACKUP_DIR}/${FILENAME}"

# Prune: keep only the 7 most recent backups
EXCESS=$(ls -tp "${BACKUP_DIR}"/*.sql.gz 2>/dev/null | tail -n +8)
if [ -n "$EXCESS" ]; then
    echo "$EXCESS" | xargs rm -f
    echo "==> Old backups pruned (keeping last 7)"
fi
