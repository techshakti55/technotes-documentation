# TechNotes isolated test environment

This is a real disposable UI + OAuth + Gateway + Notes + PostgreSQL + MongoDB
environment. It is NOT the production EC2 and it does not connect to production.
No new EC2 is required. GitHub Actions usage/storage limits still apply.

## What happens in CI

1. A hosted Ubuntu runner checks out this harness and the four source commits in
   `versions.json`. A component PR can override only its component with its SHA.
2. `prepare.py` generates a random test password and a new PKCS12 signing key.
   It creates a fresh test admin through the existing OAuth bootstrap code.
3. Separate test PostgreSQL/MongoDB containers start. Java `clean verify` runs.
4. Docker builds all four applications. No production images/secrets are used.
5. Chromium signs in through the actual React PKCE callback. It verifies profile,
   unauthorized/malformed-token rejection, category creation, draft isolation,
   missing/stale If-Match rejection, edit/submit/publish and anonymous reader.
6. Test containers and volumes are removed even if tests fail. No token traces,
   HAR files, screenshots, session storage or environment files are uploaded.

This checks the listed first-live flows; it is not a comprehensive security,
browser compatibility or performance suite. Mobile clock skew is not simulated.
The test environment uses HTTP on loopback. HTTPS/Caddy must also be verified in
production after deployment. Automated runtime results are in GitHub Actions;
the existence of workflow files alone does not prove a test pass.

## Local Windows setup (optional manual browser testing)

Requirements: Git, Docker Desktop Linux containers, Python 3, Node 22/npm.
Use a Windows PowerShell terminal; these are not AWS Ubuntu commands.

```powershell
cd D:\TechNotes\technotes-documentation
git switch main
git pull --ff-only origin main
cd deployment\test
Unblock-File .\test.ps1
.\test.ps1 start
```

First start downloads/builds images and may take several minutes. Four Java
services, databases and a browser use substantial RAM. On a slow laptop, close
the previous local stack first; use CI for routine automated checks instead.
No background hosted manual test website remains after a CI job finishes.

Open **http://localhost:25173**. Test admin email is
`test-admin@example.invalid`. Its randomly generated password is in this test
folder's `.env`; read it locally and do not share or commit it.
React environment variables are injected by Compose Docker build arguments;
no existing UI `.env.local` is changed. Source repositories are copied into the
ignored `sources/` directory at the pinned SHAs. Your main project folders are
not modified. To test a feature ref set `$env:UI_REF='your-branch-or-sha'` before
starting; analogous `OAUTH_REF`, `NOTES_REF`, `GATEWAY_REF` overrides exist.
`prepare.py` refuses to overwrite edited source checkouts.

```powershell
.\test.ps1 test
.\test.ps1 status
.\test.ps1 stop
```

`stop` keeps test data; `reset` asks you to type `RESET TEST` and deletes only
the test database volumes. Keep the test `.env` and test key together when
reusing volumes. If you intentionally regenerate keys/passwords, reset test
volumes first. Production volumes are never referenced here.

## Port and data map

| Component | Loopback endpoint | Test data |
|---|---|---|
| UI | http://localhost:25173 | no database |
| OAuth | http://localhost:29000 | technotes_auth_test |
| Gateway | http://localhost:28080 | no database |
| Notes | http://localhost:28081 | technotes_notes_test |
| PostgreSQL | localhost:25432 | technotes-test_postgres-test volume |
| MongoDB | localhost:25417 | technotes-test_mongo-test volume |

MongoDB has no authentication ONLY in this disposable loopback test setup.
Ports bind to 127.0.0.1 and it uses a separate Compose network. Do not deploy this
Compose file to AWS, expose these ports, or put real/personal data in it.

## Branch and release process

Feature PR -> verification + disposable integration -> merge -> versioned image
publication -> choose image digest -> deploy -> production smoke test.
Currently UI uses PR -> main because no develop branch existed. Existing backend
develop/main branches keep their present workflow. Do not merge a failed check.
Integration is centralized so there is one environment definition to maintain.
The SHA manifest gives repeatable cross-service combinations; update it through
a tested PR when adopting a new component baseline.

## AWS work remaining

No AWS credential, IAM policy, EC2 configuration, production database or running
container is changed by these CI files. Image publishing uses GitHub Container
Registry with GITHUB_TOKEN; no AWS access key is needed.

Next, inspect the EC2 SSM agent/role and GHCR pull access. Choose OIDC plus a
restricted SSM deployment command or another inspected delivery mechanism.
Add production deployment locking, backup/preflight, digest-based Compose update,
health checks and application-image rollback. Database migrations need their own
compatibility/restore plan; rolling back an image does not undo a migration.
This stage deliberately does not claim automatic production deployment is ready.
Until that AWS step is complete, use the existing reviewed deployment process.
