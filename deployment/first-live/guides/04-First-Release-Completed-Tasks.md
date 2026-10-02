# TechNotes — First Release: Completed Tasks

**Owner:** Shakti Singh  
**Release:** First Live Release / Phase 1  
**Record date:** 2 October 2026  
**Website:** https://technotes.co.in  
**Status:** First-release website live hai; public reading aur admin publishing workflow user ne verify kiya hai.

## 1. Pehli release mein humne kya deliver kiya?

Visitor bina login ke published Java/Spring notes padh sakta hai. Admin login karke categories aur notes create karta hai, draft edit/save karta hai, review ke liye submit karta hai aur publish karta hai. Published note public website par dikhai deta hai.

Iske liye React UI, OAuth, Notes service, API Gateway, PostgreSQL, MongoDB aur Caddy AWS EC2 par run ho rahe hain. HTTPS, stable public IP aur database backups bhi setup hain.

> “Complete” ka matlab yahan first-release scope ka implemented aur recorded working behavior hai. OAuth/Notes ka har future feature complete nahi hai. Yeh document ek new automated security audit ya load-test report nahi hai. Evidence actual session outputs aur user browser confirmations se aata hai.

## 2. Service-wise short summary

| Area | First-release result | Status |
|---|---|---|
| OAuth service | Admin login, code + PKCE token flow, signing key/JWKS, user profile integration | First-live flow working |
| Notes service | Categories, draft creation/editing, submit/publish, public list/detail | First-live workflow working |
| API Gateway | UI APIs ko Notes/OAuth tak route karna, CORS/config integration | Integrated and working |
| React UI | Public reader, login callback, admin workspace/editor/publishing | Browser verified |
| Databases | Fresh OAuth PostgreSQL aur Notes MongoDB; live content saved | Working |
| Docker/AWS | Services EC2 par containers mein | Live |
| Domain/HTTPS | Apex/auth domains, Caddy certificates/routing, Elastic IP | Verified |
| Backups | DB dump/check/upload, earlier S3 copies match, daily cron entry | Manual success; scheduled run pending |
| GitHub documentation | Deployment config/runbook/scripts develop mein saved | PR #14 merged |

## 3. OAuth service — kya complete hua?

OAuth ka kaam user ko login karwana aur protected API requests ke liye valid tokens provide karna hai. React admin password directly collect karke apne backend shortcut ko nahi bhejta; login authorization server par hota hai.

| Task | First-release behavior |
|---|---|
| PostgreSQL integration | OAuth data ke liye fresh production DB connected |
| Schema migrations | Flyway migrations/schema setup and validation |
| Initial admin account | Private configuration se initial ADMIN provision hua |
| Password handling | Provisioning existing password ko hash karke store karta hai; plaintext manual DB insert nahi |
| Login page/form | Authorization server par admin credentials se login |
| Authorization Code + PKCE | React se login → authorization → callback → token flow integrated |
| Public browser client | `technotes-web`; browser client secret ki requirement nahi |
| Production callback | `https://technotes.co.in/auth/callback` |
| Production issuer | `https://auth.technotes.co.in` |
| Signing key | Preserved PKCS12 private key production container mein mounted |
| JWKS | Public key endpoint responds; token validators ko keys milti hain |
| User profile | `/api/v1/users/me` UI/Gateway integration mein available |
| Docker runtime | OAuth container PostgreSQL se connect karke successfully started |
| Browser acceptance | New Elastic IP/DNS ke baad admin login user-verified |

### OAuth first-live endpoint map

| Method | Endpoint | Kaam |
|---|---|---|
| GET | `/oauth2/authorize` | Authorization start; code + PKCE flow |
| GET | `/login` | Login screen |
| POST | `/login` | Framework login form submission |
| POST | `/oauth2/token` | Code + verifier exchange |
| GET | `/oauth2/jwks` | Public signing keys |
| GET | `/api/v1/users/me` | Protected profile, Gateway ke through |

**Evidence:** OAuth started log, JWKS JSON, earlier integration profile response, aur actual browser login confirmation.

**Important limit:** Public signup, forgot-password UI, additional identity providers, complete key rotation/revocation operations aur stronger session-persistence behavior is first-release completion statement ka part nahi. Bootstrap `.env` OWNER_PASSWORD edit karna existing account ka automatic reset nahi hai.

## 4. Notes service — kya complete hua?

Notes service note ko sirf save nahi karti; draft aur public version ko separate workflow se manage karti hai.

| Task | First-release behavior |
|---|---|
| MongoDB integration | Fresh production Notes database connected |
| Replica setup | Authenticated single-member `rs0` initialized |
| App DB account | Notes database ke liye separate application user |
| Category model | Single hierarchical Category model; `parentId` based design |
| Category creation | Admin UI se category create; live Java/Spring categories |
| Public categories | UI ko public category data available |
| Draft creation | New note `DRAFT` mein create hota hai |
| Note fields | Title, summary, category, tags aur full `contentMarkdown` |
| Workspace list | Admin/owner ke editable notes dikhte hain |
| Editable detail | Existing draft/detail load karke edit karna |
| Draft save/edit | PATCH + current version ke saath changes save |
| Version/concurrency | ETag/If-Match contract retained; stale-version checks bypass nahi kiye |
| Submit | `DRAFT → IN_REVIEW` |
| Publish | `IN_REVIEW → PUBLISHED` aur published snapshot |
| Public list | Published PUBLIC notes cards/list mein |
| Public detail | Full published content/code reader mein |
| Owner/security integration | Authenticated identity/author aur existing role/scope contract ke saath integration |
| Docker runtime | Notes app live MongoDB ke saath run |
| Browser acceptance | Create, edit, submit, publish aur anonymous reading user-verified |

### Notes first-live endpoint map

| Method | Endpoint | Kaam |
|---|---|---|
| GET | `/api/v1/public/categories` | Public categories |
| GET | `/api/v1/public/notes` | Published notes list |
| GET | `/api/v1/public/notes/{slug}` | Published full note |
| POST | `/api/v1/categories` | Admin category creation |
| GET | `/api/v1/notes` | Protected owner workspace list |
| POST | `/api/v1/notes` | Create draft |
| GET | `/api/v1/notes/{id}` | Editable detail/current version |
| PATCH | `/api/v1/notes/{id}` | Conditional note edit |
| POST | `/api/v1/notes/{id}/submit` | Submit for review |
| POST | `/api/v1/notes/{id}/publish` | Publish note |

**Concurrency contract:** missing required If-Match → 428; old/wrong ETag → 412. Existing implementation/contract preserve hai. Har negative case ka fresh production automated test is document ke liye repeat nahi hua.

**Important production fix:** Caddy compression ke `-zstd` ETag suffix ki wajah se save par 412 aa raha tha. Encoding directive remove karke backend ETag preserve kiya; uske baad save/submit/publish verified hua.

**Important limit:** Delete/unpublish/archive UI, public community authors, subscription-gated content aur advanced content administration abhi scope complete nahi. Single-member Mongo replica set high availability nahi deta.

## 5. API Gateway — kya complete hua?

Gateway browser API request ko correct service tak le jata hai. React ko Notes aur profile APIs ke liye public Gateway-based site URL milta hai.

| Task | First-release behavior |
|---|---|
| Public routing | Public categories/list/detail requests Notes tak |
| Protected Notes routing | Category create, note list/create/detail/edit aur workflow routes |
| Profile routing | `/api/v1/users/me` OAuth service tak |
| Production service URLs | Docker names `notes:8081`, `oauth:9000` |
| UI origin/CORS config | Production site origin and configured API methods/headers |
| Version headers | ETag/If-Match based UI workflow integration |
| Timeouts/configuration | Gateway HTTP settings environment-driven |
| Health readiness | Gateway/public Notes route readiness tested during setup |
| Docker packaging | Gateway image built and server par loaded |
| Production runtime | Gateway container through Caddy public API responses |
| Eureka decision | Direct routing; first-live deployment mein Eureka disabled |

**Evidence:** public Notes route JSON, earlier profile integration, healthy startup/readiness outputs, aur live browser APIs.

**Important limit:** Gateway routing alone authorization enforcement ka proof nahi. Backend access controls bhi required hain. New rate limits, complete production abuse testing, tracing aur multiple-instance routing this release statement mein completed nahi.

## 6. React UI — kya complete hua?

| Task | First-release behavior |
|---|---|
| Fresh UI project | React + Vite frontend built |
| Public exploration | Published notes list and category content |
| Reader UI | Full Markdown/code content visible |
| Summary description | List/card ke liye short summary field |
| OAuth login initiation | Correct auth domain authorize flow |
| Callback integration | Registered callback with code/PKCE exchange flow |
| Protected API calls | Admin workspace backend integration |
| Admin editor | Title, summary, content, category and tags input |
| Draft management | Create/load/save workflow |
| Publishing controls | Submit and publish integration |
| Production mode | Demo preview se real backend integration |
| Production build | Docker image with static files/Nginx |
| SPA routing | Production routing configuration included |
| Final acceptance | Public content and admin flow verified on live domain |

UI images/workspace local preview aur actual database content alag hain. Live accepted release real backend database use karti hai. Initial local smoke notes production migration nahi the; fresh live DB content manually/API se add hua.

**Important limit:** Long-lived login after every refresh, advanced mobile/accessibility audit, SEO completeness aur every device/browser compatibility ko verified mat assume karo. Current user-tested flow works.

## 7. AWS, domain aur Docker — kya complete hua?

| Task | Result |
|---|---|
| EC2 launch | Mumbai t3.small Ubuntu x86_64 host |
| Server access | EC2 Instance Connect browser terminal working |
| Docker installation | Docker Engine/Compose; hello-world successful |
| Swap | 2 GiB swap configured and verified |
| Image transfer/load | Four `technotes-*:first-live` images loaded |
| Compose stack | UI, Gateway, OAuth, Notes, databases, proxy and init job configured |
| Persistence | Named DB/Caddy volumes configured; content available in live DB |
| Private configuration | `.env`/key files privately configured and permissions set |
| Public entry | Caddy 80/443 routing |
| GoDaddy DNS | Apex/auth A records updated |
| HTTPS | Site HTTP 200 and auth JWKS over HTTPS |
| Elastic IP | `43.205.62.80` associated and both domains resolve |
| Public/internal separation | Only proxy public ports in recorded Compose config |
| Final cutover check | Laptop/server DNS/HTTPS and browser login/public view verified |

Current runtime `/home/ubuntu/technotes-deployment`; EC2 instance `i-07284b353e2fae538`. AMI OS verified hai; exact AMI ID/full network/disk configuration export pending, so undocumented fields guessed nahi hain.

## 8. Backups — kya complete hua, kya remaining hai?

### Complete

- PostgreSQL custom archive aur Mongo compressed dump banaye.
- Basic archive/gzip validation successful.
- Earlier OAuth archive separate test DB mein restore hua; expected tables listed.
- Mongo isolated restore user ne complete report ki.
- EC2 IAM role attached; CLI assumed-role identity verified.
- Private S3 `production-backups/` prefix mein files uploaded.
- Earlier two S3 backups download karke local originals se `cmp MATCH` verified.
- Backup script with lock, checksums and fail-on-error behavior added.
- Latest manual script run 14 notes/14 revisions/2 categories ke saath successful.
- Daily cron entry installed: 03:00 IST on UTC server.

### Abhi pending

First scheduled run ka result, full encrypted secret/config recovery set, latest complete restore rehearsal, retention, backup.log rotation aur failure notification. Current database archives signing key/.env/Caddy state ka backup nahi hain.

**Simple status:** Manual backups working; daily schedule configured; first automatic-run confirmation remaining.

## 9. Content aur first-release testing

Recorded 14 published educational notes mein HashMap, immutable classes, Object methods, equals/hashCode, equality comparison, garbage collection, Spring annotations, Java 8, Optional, Streams, concurrent maps, bean lifecycle aur Singleton cover hue.

Admin workflow testing content add karte waqt hui. Singleton note se final save/submit/publish/public-read flow dobara user ne verify kiya.

10-note import authenticated APIs se hua, raw database insertion se nahi. All ten public-detail verification messages successful the. Category count latest dump mein 2 tha.

Java example programs ki compilation ya exhaustive correctness testing is release-acceptance document mein claim nahi. Yeh deployed workflow completion record hai.

## 10. GitHub/documentation ka completed task

Deployment config aur existing backup script GitHub documentation repo ke `develop/deployment/first-live/` mein saved hain.

[PR #14](https://github.com/techshakti55/technotes-documentation/pull/14) merged into develop. Commit `39b4b5c`.

Included: Compose, Caddy fix, placeholder env example, ignore/line-ending rules, preparation/Mongo bootstrap/backup scripts, operations runbook. Private env values, key files, DB archives aur image bundles commit nahi hue.

Expanded AWS guides aur yeh release task document is documentation batch mein published hain. Associated PR se develop merge status check karo. Deployment addition ka main release record cutoff par pending hai.

## 11. First release ke baad next small tasks

| Task | Kyun | Current state |
|---|---|---|
| First scheduled backup check | Automation actually executed confirm karna | Pending |
| Keys/config encrypted recovery | Database restore alone complete app recovery nahi | Pending |
| Planned EC2 reboot check | Host restart ke baad apps/data recover verify | Pending |
| Retention/alerts/cost review | Continuous operations manageable rakhna | Pending |
| Image version manifest | Next update/rollback exact version identify | Pending |
| Combined docs push and main release | Final documentation primary branch par | Pending |

Subscriptions/blog/delete jaise features next phase mein design honge; first-live complete record mein unhe add nahi kiya.

## 12. Kisi ko ek paragraph mein release explain karni ho

> TechNotes ki first live release AWS par HTTPS ke saath deploy ho gayi hai. Ismein React UI, OAuth login service, Notes service aur API Gateway integrated hain. Visitor bina login published notes padh sakta hai; admin categories/notes create karke draft save, submit aur publish kar sakta hai. PostgreSQL aur MongoDB live data store kar rahe hain. Static public IP aur private S3 database backups setup hain. Manual backup verified aur daily schedule configured hai. Ab scheduled-run confirmation, full recovery checks aur operational improvements remaining hain; subscriptions, blogging aur public signup next phases ka scope hain.
