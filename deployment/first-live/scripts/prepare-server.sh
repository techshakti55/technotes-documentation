#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v docker >/dev/null
command -v openssl >/dev/null
[[ -f .env ]] || { echo 'Copy .env.example to .env and fill values locally first.'; exit 1; }
if grep -q REPLACE_ME .env; then echo 'Fill every REPLACE_ME value in .env first.'; exit 1; fi
[[ -f secrets/oauth.p12 ]] || { echo 'Privately copy existing signing key to secrets/oauth.p12 first.'; exit 1; }
chmod 600 .env
mkdir -p secrets backups
chmod 700 secrets backups
# Mongo image user is uid/gid 999; signing-key reader is uid/gid 10001.
# Root owns the parent directory; containers receive file binds only.
if [[ ! -f secrets/mongo-keyfile ]]; then
    umask 077
    openssl rand -base64 756 > secrets/mongo-keyfile
fi
sudo chown 999:999 secrets/mongo-keyfile
sudo chmod 400 secrets/mongo-keyfile
sudo chown 10001:10001 secrets/oauth.p12
sudo chmod 400 secrets/oauth.p12
# Quiet validation avoids dumping environment values.
docker compose --env-file .env config --quiet
echo 'Configuration validated. No containers started.'
