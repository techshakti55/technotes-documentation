#!/usr/bin/env bash
# Install into the production deployment folder AFTER registry access is set up.
# Only UI changes. No database migration, volume deletion or Compose down.
set -euo pipefail
umask 077
cd "$(dirname "$0")/.."
image=${1:-}
if [[ ! "$image" =~ ^ghcr\.io/techshakti55/technotes-ui@sha256:[a-f0-9]{64}$ ]]; then
  echo 'Usage: bash scripts/deploy-ui.sh ghcr.io/techshakti55/technotes-ui@sha256:<64 hex digest>' >&2
  exit 2
fi
command -v flock >/dev/null
exec 9>.ui-deploy.lock
flock -n 9 || { echo 'Another UI deployment is running.' >&2; exit 1; }
test -s compose.yaml
override=ui.release.yaml
if [[ -e "$override" ]] && ! head -n 1 "$override" | grep -Fxq '# Managed by deploy-ui.sh'; then
  echo 'Existing ui.release.yaml is not owned by this script; refusing to overwrite.' >&2
  exit 1
fi
dc=(sudo -n docker compose -f compose.yaml)
[[ ! -f "$override" ]] || dc+=(-f "$override")
container=$("${dc[@]}" ps -q ui)
test -n "$container" || { echo 'Existing production UI is not running.' >&2; exit 1; }
old_image=$(sudo -n docker inspect --format '{{.Image}}' "$container")
# Download first; failed registry access never restarts the live UI.
sudo -n docker pull "$image"
revision=$(sudo -n docker image inspect --format '{{index .Config.Labels "org.opencontainers.image.revision"}}' "$image")
[[ "$revision" =~ ^[a-f0-9]{40}$ ]] || { echo 'Missing source revision label.' >&2; exit 1; }
rollback=$(mktemp .ui-rollback.XXXXXX)
if [[ -f "$override" ]]; then
  cp "$override" "$rollback"
else
  printf '# Managed by deploy-ui.sh\nservices:\n  ui:\n    image: %s\n    pull_policy: never\n' "$old_image" > "$rollback"
fi
new_config=$(mktemp .ui-release.XXXXXX)
printf '# Managed by deploy-ui.sh\nservices:\n  ui:\n    image: %s\n    pull_policy: never\n' "$image" > "$new_config"
sudo -n docker compose -f compose.yaml -f "$new_config" config --quiet
changed=false
recover() {
  result=$?
  trap - EXIT
  if [[ "$changed" == true && "$result" -ne 0 ]]; then
    cp "$rollback" "$override"
    echo 'UI deployment failed; restoring previous image.' >&2
    if ! sudo -n docker compose -f compose.yaml -f "$override" up -d --no-deps --force-recreate ui; then
      echo 'ROLLBACK FAILED: inspect UI logs immediately.' >&2
    fi
  fi
  rm -f "$new_config"
  if [[ "$result" -eq 0 ]]; then
    mv "$rollback" .ui-rollback.last.yaml
  else
    rm -f "$rollback"
  fi
  exit "$result"
}
trap recover EXIT
mv "$new_config" "$override"
changed=true
sudo -n docker compose -f compose.yaml -f "$override" up -d --no-deps --force-recreate ui
for attempt in $(seq 1 30); do
  container=$(sudo -n docker compose -f compose.yaml -f "$override" ps -q ui)
  if [[ -n "$container" ]] &&
     sudo -n docker exec "$container" wget -q -O /dev/null http://127.0.0.1/ &&
     curl -fsS --connect-timeout 5 --max-time 10 -o /dev/null https://technotes.co.in/; then
    echo "UI DEPLOYED: source $revision"
    echo "Image: $image"
    echo 'Now check browser login and public notes. Automated HTTP checks do not prove those flows.'
    exit 0
  fi
  sleep 2
done
echo 'UI readiness timed out.' >&2
exit 1
