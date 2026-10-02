# CI, test environment and next AWS deployment step

## What is implemented in GitHub

The test harness is in [deployment/test](../../test/README.md).
It defines separate databases, a generated test signing key/account and loopback
ports. GitHub Actions can run the real browser login and note workflow without
another EC2. Existing production data/configuration remains separate.

Each application repository gets a PR integration gate using the shared pinned
harness. It overrides only the changed application's source SHA; other components
use the recorded `versions.json` baseline. Java checks and Docker/browser tests
must pass before a main push can publish that application's Docker image.
Images are published to `ghcr.io/techshakti55/<repository>:sha-<commit>` and the
registry digest is written in the successful job's summary. Main publication does
not deploy to EC2. Existing OAuth/Gateway verification workflows remain in place.

## How to check a change

1. Create a feature branch from the current integration branch.
2. Push code and open a PR. View the Actions/checks tab.
3. Fix failed checks. Never interpret skipped tests as passed.
4. Merge only after successful verification. For backends, keep develop -> main
   promotion; UI currently uses feature -> main.
5. Main's release workflow repeats integration and publishes an image.
6. Record the image digest and its source SHA. Do not deploy an untested mutable
   `latest` tag. Use the same backend digest for promotion. UI currently has
   environment-specific builds because Vite embeds the public URLs.

Automatic branch protection / required-review environment settings have not been
installed by the GitHub connector. Those administrative settings must be checked
in GitHub Settings. A GitHub Environment name alone is not a test server.

## AWS integration to do together

Before pipeline-driven deployment, inspect the EC2 IAM instance profile and SSM
agent status. The existing backup role is for S3 backups; do not assume it already
allows Systems Manager. Establish narrowly scoped GitHub OIDC/SSM deployment
access, or choose another inspected transport. Do not paste AWS access keys into
repository files and do not run PR code with production credentials.

New GHCR packages may be private. Confirm their visibility and EC2 read access;
public source code does not automatically make the package public. Decide public
images (only reviewed non-secret images) or scoped authenticated pulls. Do not
claim deployment is ready until a real EC2 pull succeeds.

## Prepared one-command UI deployment script

`scripts/deploy-ui.sh` is prepared for the current production layout. It is not
automatically installed/run on EC2 by a repository merge. Review and install it
after registry access is confirmed. It accepts only the UI repository's exact
digest, obtains a deploy lock, downloads first, verifies a source revision label,
updates only UI, checks local/public HTTP readiness and restores the previous
UI image/configuration on a detected failure. It never deletes database volumes.

Example after setup (replace digest, do not run placeholders):

```bash
cd ~/technotes-deployment
bash scripts/deploy-ui.sh ghcr.io/techshakti55/technotes-ui@sha256:<actual-digest>
```

The script persists the selected image in `ui.release.yaml`. Once this method is
adopted, normal compose commands must include that override:

```bash
sudo docker compose -f compose.yaml -f ui.release.yaml ps -a
sudo docker compose -f compose.yaml -f ui.release.yaml up -d
```

Running `compose up` with only the old base file could select the old first-live
image again. A later deployment refactor can move all service image references
into one reviewed release manifest. This first script handles UI only; backend
deployment, migration compatibility, failure alerting and full browser post-deploy
checks are still separate work. A passing HTTP homepage does not prove admin login.

## Previously verified operations (2 October 2026)

User verified recovery archive decryption/listing and byte-for-byte S3 match for
`recovery-20261002T154047Z.tar.gz.gpg`. It contains .env, OAuth key, Mongo key,
Compose, Caddyfile and scripts; its passphrase is held separately by the user.
No secret values are recorded here. Caddy volume state is not in this archive.

EC2 reboot test: Docker enabled at boot; services returned automatically,
PostgreSQL/MongoDB healthy; user verified HTTPS/public APIs/JWKS and Incognito
login/persisted notes after restart. No manual compose up was needed.
Daily cron installation is verified but its first scheduled execution is not yet
observed. The configured 21:30 UTC run is 03:00 IST on the following day.
