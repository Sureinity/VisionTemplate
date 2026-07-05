#!/usr/bin/env bash
set -euo pipefail

APP_DIR="/var/www/VisionTemplate"
ENV_FILE="$APP_DIR/.env"
BACKUP_DIR="/var/backups/postgres"
RETENTION_DAYS="7"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_FILE="$BACKUP_DIR/vision_postgres_${TIMESTAMP}.sql.gz"

if [ ! -f "$ENV_FILE" ]; then
  echo "Missing env file: $ENV_FILE" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

: "${POSTGRES_USER:?POSTGRES_USER must be set in $ENV_FILE}"
: "${POSTGRES_DB:?POSTGRES_DB must be set in $ENV_FILE}"

mkdir -p "$BACKUP_DIR"

TMP_BACKUP_FILE="$BACKUP_FILE.tmp"
trap 'rm -f "$TMP_BACKUP_FILE"' EXIT

docker exec vision_postgres pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" | gzip > "$TMP_BACKUP_FILE"
mv "$TMP_BACKUP_FILE" "$BACKUP_FILE"
trap - EXIT

find "$BACKUP_DIR" -type f -name '*.sql.gz' -mtime +"$RETENTION_DAYS" -delete

echo "Postgres backup written to $BACKUP_FILE"

# Crontab example for daily backups at about 02:00:
# 0 2 * * * /var/www/VisionTemplate/backup.sh >> /var/log/vision-postgres-backup.log 2>&1
