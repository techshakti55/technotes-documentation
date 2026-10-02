#!/usr/bin/env bash
set -euo pipefail
umask 077

export PATH=/usr/local/bin:/usr/bin:/bin
cd /home/ubuntu/technotes-deployment

exec 9>backups/.backup.lock
flock -n 9 || {
  echo "Another backup is running."
  exit 1
}

stamp=$(date -u +%Y%m%dT%H%M%SZ)
folder="backups/$stamp"
destination="s3://technotes-deploy-20261002-shakti/production-backups/$stamp"

mkdir -p "$folder"

sudo -n docker compose exec -T postgres sh -ec \
  'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc' \
  > "$folder/oauth.dump"

sudo -n docker compose exec -T mongodb sh -ec \
  'mongodump --username "$MONGO_INITDB_ROOT_USERNAME" --password "$MONGO_INITDB_ROOT_PASSWORD" --authenticationDatabase admin --db technotes_notes --archive --gzip' \
  > "$folder/notes.archive.gz"

test -s "$folder/oauth.dump"
test -s "$folder/notes.archive.gz"

sudo -n docker compose exec -T postgres pg_restore --list \
  < "$folder/oauth.dump" > /dev/null

gzip -t "$folder/notes.archive.gz"

(
  cd "$folder"
  sha256sum oauth.dump notes.archive.gz > SHA256SUMS
)

aws s3 cp "$folder/" "$destination/" \
  --recursive --region ap-south-1 --sse AES256 \
  --only-show-errors --no-cli-pager

echo "BACKUP UPLOADED: $destination/"
