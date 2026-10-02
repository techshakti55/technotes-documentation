# TechNotes — First-Live Release Status & Developer Handover

**Owner:** Shakti Singh  
**Cutoff:** 2 October 2026, after first-live deployment and daily-backup schedule setup  
**Purpose:** New developer/new chat ko clear state dena; kya working hai, kahan config hai aur kya pending hai.

Companion documents: [AWS Complete Guide](01-AWS-Deployment-Complete-Guide.md) and [Daily Operations](02-Daily-Operations-Quick-Reference.md).

## 1. Project ko simple words mein samjho

TechNotes Java/Spring interview preparation notes website hai. Visitor published notes without login read karta hai. Admin OAuth login ke baad categories/notes manage karta hai. Draft create/edit → submit for review → publish → public reader flow implemented and user-verified hai.

First release intentionally small hai. Abhi payment, subscription, public signup, community blogging, delete/archive UI ya multiple-host production architecture add nahi hui. Existing first-live endpoint names preserve karne hain; future features additive reviewed changes se ayengi.

Learning goals Java/backend practice aur company-style Git workflow bhi hain. Production operation aur learning experiment alag contexts mein clearly distinguish karo.

## 2. Release outcome

**Working:** HTTPS site, OAuth login, admin workspace, category creation, draft save/edit/submit/publish, anonymous reader, live Mongo/Postgres persistence, static public IP, private S3 database backups.

**Installed but first scheduled execution pending:** daily cron backup 03:00 IST.

**Not yet fully verified:** whole-host reboot recovery, complete encrypted secret/config restore, load capacity and all operational alerts/retention.

A new contributor ko “everything production-ready” bolkar remaining tasks hide nahi karni. Core first-live works; this is single-host first-live, not high availability.

## 3. Repositories aur Git status

| Repository | Purpose |
|---|---|
| [technotes-ui](https://github.com/techshakti55/technotes-ui) | React frontend / production Docker UI |
| [technotes-user-oauth-service](https://github.com/techshakti55/technotes-user-oauth-service) | Login / OAuth / profile |
| [technotes-notes-service](https://github.com/techshakti55/technotes-notes-service) | Notes/categories/workflow |
| [technotes-api-gateway](https://github.com/techshakti55/technotes-api-gateway) | API routing |
| [technotes-documentation](https://github.com/techshakti55/technotes-documentation) | Contracts, design, deployment/runbook |
| [technotes-eureka-server](https://github.com/techshakti55/technotes-eureka-server) | Other learning/infrastructure track; disabled here |
| [technotes-config-server](https://github.com/techshakti55/technotes-config-server) | Other learning/infrastructure track; not required here |

Known completed documentation change:

- [PR #14](https://github.com/techshakti55/technotes-documentation/pull/14): first-live deployment configuration and backup script.
- Squash-merged into `develop`; commit `39b4b5cd3a1621c98b9d36b71758152fbbb99e10`.
- Folder [deployment/first-live on develop](https://github.com/techshakti55/technotes-documentation/tree/develop/deployment/first-live).
- `develop → main` release for this deployment addition not performed in this session.
- These expanded guides are published together in this documentation change. Check the associated PR for current develop/main merge status.

Other repositories ke complete current branch heads and all four images' source commit mapping is document cutoff par independently rechecked nahi. Release tag/digest manifest pending hai. Before new coding, fetch/status inspect karo.

## 4. Runtime inventory

| Item | Recorded |
|---|---|
| AWS region / zone | `ap-south-1` / `ap-south-1b` |
| EC2 | `i-07284b353e2fae538`, `t3.small` |
| OS/architecture | Ubuntu 24.04.4 LTS / x86_64 |
| RAM/swap | About 1.9 GiB usable RAM / 2 GiB swap |
| Disk | About 19 GiB root shown; EBS exact type/ID not recorded |
| Public stable IP | `43.205.62.80` |
| Private IP | `172.31.4.208` |
| Website / issuer | `https://technotes.co.in` / `https://auth.technotes.co.in` |
| UI callback | `https://technotes.co.in/auth/callback` |
| Runtime path | `/home/ubuntu/technotes-deployment` |
| Compose project | `technotes-production` |
| Current admin connection | AWS browser EC2 Instance Connect, user ubuntu |
| Backup bucket / region | `technotes-deploy-20261002-shakti` / Mumbai |

Exact AMI ID, EBS encryption/DeleteOnTermination values, VPC/subnet IDs, detailed IAM-user policy and final Budget alert settings are not fully captured. Inventory needs future console export; do not invent them.

Old `52.66.243.132` public IP is historical. README/new examples use Elastic IP. SSH .pem remains privately stored on owner laptop; do not attach it to GitHub.

## 5. Services and routing

| Compose service | Runtime target | Function | External path |
|---|---|---|---|
| `proxy` | Caddy, 80/443 | HTTPS/domain routing | Public entry point |
| `ui` | Nginx port 80 | Built React files | Apex non-API requests |
| `gateway` | Port 8080 | API routing | Apex `/api/v1/*` through proxy |
| `oauth` | Port 9000 | Login/tokens/JWKS | auth host and profile via Gateway |
| `notes` | Port 8081 | Note APIs | Through Gateway |
| `postgres` | Port 5432 | OAuth DB | Internal Docker network |
| `mongodb` | Port 27017 | Notes DB | Internal Docker network |
| `mongo-init` | One-shot job | Replica/user initialization | No public listener |

Compose explicitly disables Eureka for this deployment. Current services are direct-routed by Docker names. Eureka not running is not automatically an error here.

Application images loaded: `technotes-ui:first-live`, `technotes-oauth:first-live`, `technotes-notes:first-live`, `technotes-gateway:first-live`. Infrastructure images recorded: `postgres:17`, `mongo:7.0`, `caddy:2-alpine`. These tags are mutable; exact digest inventory needs follow-up.

## 6. Configuration ownership

| File | What it holds | Handling |
|---|---|---|
| `compose.yaml` | Services, env mappings, networks, volumes | Git versioned |
| `Caddyfile` | Public routing | Git versioned; compression fix preserve |
| `.env.example` | Variable names/placeholders | Git versioned |
| `.env` | Private DB/admin/key passwords | Server/local private only |
| `scripts/prepare-server.sh` | Key file permissions / validation | Git versioned |
| `scripts/init-mongo.js` | Replica/app user bootstrap | Git versioned |
| `scripts/backup.sh` | Dump + check + S3 upload | Git versioned |
| `secrets/oauth.p12` | OAuth private signing key | No Git; restrict permissions |
| `secrets/mongo-keyfile` | Mongo replica authentication | No Git |
| `backups/` | Dumps/check files/backup log | No Git |
| Docker volumes | Persistent database/Caddy runtime data | Not a Git artifact |

Git folder is reconstructed from prepared package plus documented server fixes, not a byte-for-byte server export. Additional private/server-only edits must be compared before applying files back to production.

Never replace live `.env` from template, rotate existing keys casually, reset Mongo volumes for a startup issue, or assume Git checkout updates server automatically.

## 7. First-live endpoint map

Existing contract details remain in docs/first-live and integration contracts. This table is a navigation map, not a new/renamed API proposal.

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/v1/public/categories` | Active public categories |
| GET | `/api/v1/public/notes` | Published public cards/list |
| GET | `/api/v1/public/notes/{slug}` | Published snapshot/body |
| POST | `/api/v1/categories` | Admin create category |
| GET | `/api/v1/notes` | Owner-scoped workspace list |
| POST | `/api/v1/notes` | Create DRAFT |
| GET | `/api/v1/notes/{id}` | Editable detail/current ETag |
| PATCH | `/api/v1/notes/{id}` | Conditional edit |
| POST | `/api/v1/notes/{id}/submit` | DRAFT → IN_REVIEW |
| POST | `/api/v1/notes/{id}/publish` | IN_REVIEW → PUBLISHED |
| GET | `/api/v1/users/me` | User profile via Gateway |

OAuth framework routes are on auth host: authorize, login GET/POST, token POST, JWKS GET. Callback is frontend route. Actuator health is operational infrastructure, not a new public first-live feature.

Protected requests require the implemented token/role/scope rules. Notes transition/write concurrency uses current If-Match. Missing header 428 / stale header 412 contract remains. Do not add a parallel “easy publish” endpoint that bypasses workflow/security.

## 8. Data model assumptions a new developer must preserve

- One hierarchical Category model with parentId, not a separate SubCategory class.
- Summary is short description; body is contentMarkdown.
- Create-note author identity comes from authenticated user, not arbitrary UI author ID.
- Public card/list excludes full Markdown body.
- Public detail returns published immutable revision.
- Draft/private/unpublished content is not public content.
- Protected list is owner-scoped.
- Admin category creation requires role/scope rules.
- Publish is an atomic snapshot operation; audited admin self-publish exception belongs to existing implementation.
- A real stale edit must still fail even after proxy ETag fix.

First-live scope has no delete UI/functionality. New content cleanup or unpublish feature needs an explicit reviewed design, not manual DB deletes as routine UI maintenance.

## 9. Databases/admin/signing key

**Production fresh databases** were used. Old Windows local data wasn't migrated; local practice environment remains separate.

Postgres `technotes_auth`: Flyway migrations, validated schema, initial owner ADMIN provisioner. Password hashed by app provisioning; existing admin isn't overwritten on every restart. Changing bootstrap OWNER_PASSWORD in `.env` is not the existing-account reset process.

Mongo `technotes_notes`: authenticated single-member `rs0`, Notes app read/write user, collections categories/notes/note_revisions. A single-member replica set has no second node for failover.

Preserved OAuth PKCS12 key alias: `technotes-oauth-signing`. The correct keystore/key passwords are private. Key entry was checked with keytool; public JWKS responded successfully. Existing signing-key reuse was intentional; rotation/revocation plan is not yet part of this release.

## 10. Acceptance and content record

| Area | Completed evidence |
|---|---|
| Public HTTPS | curl 200 from server and laptop |
| Auth endpoint | Public JWKS JSON |
| DNS static-IP cutover | Both A names resolved new IP |
| Admin browser workflow | User confirmed after cache update |
| Draft edits/transitions | User confirmed after ETag fix |
| Reader | Public notes/detail verified by user |
| Bulk import | 10 notes all public detail verified in script output |
| Post-import content | 14 note/revision docs, 2 categories dumped |

Recorded content sequence:

1. Java HashMap internals.
2. How to create an immutable class.
3. Why immutable objects/classes are useful.
4. Java Object class and 11 methods.
5. equals/hashCode contract and HashMap.
6. `==` vs equals.
7. Java garbage collection.
8. Spring Core annotations.
9. Java 8 features.
10. Optional.
11. Streams map/flatMap/collect.
12. ConcurrentHashMap vs HashMap vs synchronized map.
13. Spring bean lifecycle and dependency injection.
14. Singleton implementation, breaking mechanisms and prevention.

Two categories observed: Java and Spring. Public-note counts/content can evolve. Content has educational examples; Java sample programs aren't claimed compiled/tested by this documentation task.

The 10-note importer used authenticated APIs and normal workflow, not raw DB inserts. Its folder on EC2 was `~/technotes-deployment/technotes-interview-import`. Production token input was private; never store it in source. Avoid rerunning blindly or generating duplicate notes.

## 11. Known fixes and decisions

| Decision/fix | Reason | Preserve in future work |
|---|---|---|
| Browser Instance Connect | Direct laptop SSH timeout | Working access route, inspect network separately |
| Jammy Maven build image | Tested builder replacement ran after exec format error | Recheck actual Dockerfiles before next build |
| Fresh DBs | First release didn't need old local data | Don't mix Windows local dataset with production |
| Preserve signing key | Keep expected token signing identity | Secret stays private; don't overwrite |
| Omit Caddy encode directive | Compression changed ETag; save got 412 | Concurrency still enforced |
| Elastic IP | Stable DNS destination | Both @ and auth point to current IP |
| EC2 IAM role | Backup AWS CLI lacked credentials | No long-term access keys on server |
| Private S3 backups | Local backups alone on same server insufficient | Prefix-scoped permissions + verified copies |
| Ubuntu cron | Daily unattended dumps/uploads | Scheduled-run result still needs check |

Current browser works after Auth DNS stale old IP was resolved. Do not assume the earlier timeout still exists or restart all services unnecessarily.

## 12. Backup inventory and proof

| Run | Record |
|---|---|
| `20261002T123834Z` | First archives; Postgres separate-test restore table list successful, Mongo separate restore reported complete |
| `20261002T132908Z` | After import; S3 OAuth 35,729 bytes / Notes 38,168 bytes listed; both downloaded copies cmp MATCH |
| `20261002T142855Z` | Backup script manual success after Singleton: 14 notes, 14 revisions, 2 categories; checksum manifest generated/uploaded by script |

Current script makes timestamp subfolders; first older manual dumps had flat timestamp filenames. Don't confuse local old filename pattern and current S3 filename pattern.

Backup role is EC2 attached `TechNotesProductionBackupRole`; policy `TechNotesProductionBackupAccess`. Object rights Put/Get under `production-backups/*`; ListBucket restricted to prefix. No DeleteObject permission. S3 private/SSE-S3.

Schedule `30 21 * * * ...backup.sh...` in ubuntu crontab, server UTC = 03:00 IST daily. On 2 October evening entry was installed; first next scheduled run is 3 October 03:00 IST if server/resources remain available.

Stored DB archives don't include signing key, private .env, Mongo keyfile or Caddy state. Full recovery package not yet complete.

## 13. Pending work: priority and proof needed

| Priority | Task | Completion proof |
|---|---|---|
| Next morning | First scheduled backup | Log timestamp/success + three objects in new S3 prefix |
| High | Encrypted off-server keys/config recovery | Restricted encrypted copy and usable restore procedure |
| High | Full host reboot rehearsal | Reconnect, Docker/apps ready, data retained, login/public flow pass |
| High | Current restore rehearsal | Separate test databases restore and expected records/readability |
| Before continued releases | Immutable image inventory | Source commit, distinct tags/digests, retained previous version |
| Operational | Retention and log rotation | Agreed keep-period and tested policy/script with intentional permissions |
| Operational | Backup failure alert | Simulated failure produces notification |
| Operational | Budget/credit monitoring | Account actual forecast and alerts reviewed |
| Documentation | Develop → main | PR merged, files visible on main |
| Optional domain polish | www redirect/HTTPS | www browser test and intentional Caddy/DNS behavior |
| Capacity | Representative load check | Resource/latency/failure observations under known load |

EC2 reboot can cause downtime; do it in a planned window with successful backup and recovery access. This document does not initiate reboot. Restore-test DBs from earlier exercises may remain; cleanup is not confirmed.

## 14. What to tell a new developer / new chat

Copy this starting context and link these documents:

> I am Shakti Singh, building TechNotes with Java/Spring and React. First-live site https://technotes.co.in is running on a single Ubuntu amd64 EC2 t3.small in Mumbai. Caddy routes the site to UI/Gateway and auth.technotes.co.in to OAuth. PostgreSQL stores OAuth data and MongoDB stores Notes. The first-live endpoint contract must stay stable. Public reading, admin login and draft/save/submit/publish are user-verified. There are 14 notes and two categories at the latest recorded backup. Elastic IP is 43.205.62.80. Runtime folder is /home/ubuntu/technotes-deployment. Backup script manually succeeded, S3 copies from an earlier run matched local files, and a 03:00 IST cron entry is installed but its first scheduled run still needs confirmation. EC2 uses TechNotesProductionBackupRole, no static access keys. Deployment files are in technotes-documentation develop/deployment/first-live, PR #14 merged. Do not reset databases, overwrite secrets or invent endpoints. Inspect current branches/config first. Guide me one short command/task at a time, explicitly saying Windows PowerShell or Ubuntu terminal. Next work should focus on the documented pending operations before extra features.

## 15. New work workflow

1. Current task and affected service define karo.
2. Existing contract/source state read karo; access/config infer mat karo.
3. Main/develop current state check; feature branch create.
4. Small concrete change; appropriate verification.
5. PR with what/why/test results; develop merge per agreed workflow.
6. Production deploy is separate deliberate action; take backups/retain previous images.
7. Update status/evidence in docs after actual success.

These expanded guides and the completed-tasks document are published as one documentation batch. No deployment/source feature changes are needed to publish them.
