# TechNotes first-live deployment

Production runbook and reproducible configuration, recorded 2 October 2026.
This folder belongs to the documentation repository. The runtime directory on EC2 is `/home/ubuntu/technotes-deployment`; do not run Compose from this nested GitHub folder against the live host without deliberate deployment.

## Current release

- Site: https://technotes.co.in ; authorization server: https://auth.technotes.co.in .
- Single Ubuntu 24.04 amd64 EC2, t3.small (2 GiB RAM), 2 GiB swap, Mumbai.
- Elastic IP: `43.205.62.80`; GoDaddy A records `@` and `auth` point here.
- Fresh PostgreSQL OAuth and MongoDB Notes databases with persistent Docker volumes.
- Services: Caddy, UI, Gateway, OAuth, Notes, PostgreSQL, MongoDB and one-shot mongo-init. Eureka/Config Server are disabled for this release.
- First-live API names remain unchanged. No signup, subscriptions or blogging added.
- User verified HTTPS, anonymous note reading, admin login and create/save/submit/publish. 14 notes and 2 categories recorded at backup time.

This configuration originates from the prepared deployment package. The Caddy compression fix and backup script incorporate changes made during the guided server session. It is not a byte-for-byte export of the server filesystem; compare any additional server edits before replacing live files.

## Files

| File | Purpose |
| --- | --- |
| compose.yaml | Persistent service stack; only proxy ports 80/443 published |
| Caddyfile | Domain routing, automatic HTTPS and API proxy |
| .env.example | Placeholder-only private configuration template |
| scripts/prepare-server.sh | Signing-key/Mongo-key permissions and quiet Compose validation |
| scripts/init-mongo.js | Idempotent replica-set and Notes database-user initialization |
| scripts/backup.sh | PostgreSQL + MongoDB dump, checksums and private S3 upload |
| .gitignore | Exclude secrets, runtime data, image bundles and logs |

Scripts may arrive without executable permissions through GitHub's contents API. Use `bash scripts/prepare-server.sh` and `chmod 700 scripts/backup.sh` as described below.

## Private provisioning on a new host

Install Docker Engine, Compose, OpenSSL, AWS CLI v2, cron and util-linux (flock). Create the runtime folder as ubuntu, copy only the tracked configuration into it, and transfer the four tested `technotes-*:first-live` amd64 images separately. `pull_policy: never` means these images must already be loaded.

Create `.env` from `.env.example` only if absent; fill all placeholders privately and chmod 600. Transfer the existing OAuth PKCS12 key privately to `secrets/oauth.p12`. The known key alias is `technotes-oauth-signing`; passwords are not recorded here. Do not overwrite an existing .env or generate a replacement signing key casually.

Run key preparation with Docker permissions (the script calls docker directly); on this Ubuntu setup:

```bash
cd /home/ubuntu/technotes-deployment
sudo bash scripts/prepare-server.sh
sudo chown ubuntu:ubuntu backups
sudo chmod 700 backups
sudo docker compose --env-file .env config --quiet
sudo docker compose up -d
sudo docker compose ps -a
```

mongo-init Exit 0 is expected. Compose service_started is not HTTP readiness. Database bootstrap passwords and owner provisioning apply to new databases; changing .env does not reset an existing admin or rotate database passwords.

## Caddy ETag fix

Do not reintroduce `encode zstd gzip` on API responses without reworking the concurrency contract. In this release Caddy's encoded response ETag acquired a `-zstd` suffix; forwarding it as If-Match caused Notes to reject saves with 412 STALE_VERSION. The committed configuration preserves the backend ETag by omitting that encoding directive.

## Operations

```bash
cd /home/ubuntu/technotes-deployment
sudo docker compose ps -a
sudo docker compose logs --tail 80 oauth notes gateway proxy
curl --fail --connect-timeout 10 --max-time 30 https://technotes.co.in/api/v1/public/notes
curl --fail --connect-timeout 10 --max-time 30 https://auth.technotes.co.in/oauth2/jwks
```

Start with `sudo docker compose up -d`; stop with `sudo docker compose stop` only when downtime is intended. Never use `down -v` or delete live volumes. EC2 stop/start is different from container stop/start and has billing/availability implications. Keep the Elastic IP associated. Only SSH/HTTP/HTTPS are allowed as appropriate; database and JVM ports stay internal.

## Backups

Run as ubuntu with noninteractive sudo Docker access and the EC2 role `TechNotesProductionBackupRole`. Its `TechNotesProductionBackupAccess` policy grants PutObject/GetObject under `production-backups/*` and prefix-restricted ListBucket on `technotes-deploy-20261002-shakti`. No access keys or aws configure required. Bucket remains private; uploads use SSE-S3.

```bash
cd /home/ubuntu/technotes-deployment
mkdir -p backups
chmod 700 backups
chmod 700 scripts/backup.sh
bash -n scripts/backup.sh
./scripts/backup.sh
```

The script fails on dump, basic validation or upload errors. flock prevents overlapping runs; umask 077 restricts generated files. It validates PostgreSQL archive readability and Mongo gzip integrity, writes SHA256SUMS, then uploads all three files. These checks do not replace a restore rehearsal. It does not delete local or S3 backups. PostgreSQL and MongoDB dumps are independent points in time, not one cross-database transaction. They do not include signing keys, .env, Mongo keyfile or Caddy state.

UTC server cron, installed for ubuntu (not root):

```cron
30 21 * * * /home/ubuntu/technotes-deployment/scripts/backup.sh >> /home/ubuntu/technotes-deployment/backups/backup.log 2>&1
```

This is 03:00 IST daily. Use `crontab -e`, preserve existing entries and add this line only once. Create backup.log with mode 600. Verify with `crontab -l`; inspect with `tail -n 20 backups/backup.log`. EC2 must be running; cron does not replay a missed run.

## Evidence and remaining work

- Earlier OAuth backup restored to a separate test database; six expected tables listed. Mongo restore check was reported complete by the user.
- `20261002T132908Z`: both S3 backups downloaded and byte-compared with local originals; both MATCH.
- `20261002T142855Z`: backup script manually succeeded, including 14 Notes records, 14 revisions and 2 categories. Checksums uploaded with that run.
- Daily cron entry verified; first scheduled execution has not yet been observed.
- Full host reboot recovery, encrypted off-server configuration/key recovery, backup retention/log rotation, failure alerting, immutable image release tags and resource/load limits remain follow-up tasks.
- Existing images use mutable first-live tags. Preserve the known working image bundle privately and take backups before updates. Configuration in Git does not back up image layers or databases.

## Updating production

Change files through a feature branch and PR, review the diff, take a fresh backup, preserve previous configuration/images, and apply only intended files to the runtime directory. Never replace .env or secrets from this repository. Run quiet Compose validation and verify anonymous reading, admin login and save/submit/publish after an update. This GitHub change by itself does not deploy or restart the server.
