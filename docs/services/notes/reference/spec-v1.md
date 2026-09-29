# TechNotes — Notes Service specification

Version: 1.0 | Date: 2026-09-28 | Status: proposed implementation contract, ready for team review

**Owner: Developer 2. Shakti Singh owns User/OAuth Service.** “Node Service” in the discussion means this Java Notes Service, not a Node.js application. This is a fresh implementation plan; none of the endpoints below are claimed to exist yet. No Jira IDs have been allocated by this document.

Repository: `techshakti55/technotes-notes-service`  
Suggested destination: `docs/notes-service-spec.md`  
Companion: [User/OAuth specification](../../oauth/reference/spec-v1.md). Keep both original filenames together in the documentation repository for working relative links, or update the link when moving them into separate repositories.

## 1. Purpose and service ownership

Provide technical learning notes arranged as Java → Core Java → Collections → ArrayList → detailed note. A note contains Markdown, code blocks, a summary and tags. The service owns taxonomy, note content, ownership checks, editing and publication rules. It does not own passwords, OAuth clients, user accounts or token issuance.

| Concern | Owner / integration |
|---|---|
| Notes, taxonomy and revisions | Notes Service / MongoDB |
| Login, user IDs, roles, OAuth/OIDC | User/OAuth Service / PostgreSQL |
| External API routing | API Gateway |
| Service registration / external configuration | Eureka / Config Server |
| Images and PDFs | Future Media Service; MinIO locally, S3 later |
| Search index | Future Search Service; MongoDB remains authoritative |
| Publication notifications | Later Kafka consumers, after a reliable outbox exists |

No service reads another service's database. Notes stores `authorId` equal to the verified OAuth access-token `sub`. Author display names can be added through a bounded profile integration later; they are not needed for initial CRUD.

## 2. Milestones and limits

| Stage | Deliverable | Exit condition |
|---|---|---|
| B0 — baseline | Java application, profiles, database connectivity, health, tests, documentation | Fresh clone builds and runs on both laptops |
| M1 — private authoring | Taxonomy, secured create/read/list/update/delete of drafts | Both developers demonstrate real-token access through Gateway |
| M2 — editorial publishing | Submit/reject/publish/archive, immutable revisions, public read APIs | Drafts and private content never appear in anonymous reads |
| M3 — extensions | Media, blogs, interview Q&A, search and Kafka | Separate contracts and tickets before implementation |

Do not start all stages together. In M1 only `contentKind=NOTE` and `status=DRAFT` are supported. BLOG and INTERVIEW_QUESTION are reserved future concepts, not accepted API values. M1 requires security integration before shared deployment; unit tests can use test JWTs while Shakti develops the issuer.

## 3. Baseline and repository layout

- Java 21, Maven Wrapper, Spring Boot **3.5.x target family**, Spring MVC, Spring Data MongoDB, Validation, Actuator, OAuth2 Resource Server, JUnit and Testcontainers.
- When discovery/config dependencies are enabled, use the matching Spring Cloud **2025.0.x target family**. Pin one verified Boot patch and compatible BOM in the first baseline PR; do not use version ranges or claim an unverified patch is installed. Check maintenance/security status before release. Do not independently override Spring Security versions.
- Direct local application port: **8081**. MongoDB host port: **27018**; container port: **27017**. Database: `technotes_notes_db`.
- Profiles: `local` for laptop development; `test` for isolated tests; deployment config from environment/secrets. Local configuration may tolerate unavailable Config Server; production must not silently fall back to unsafe defaults.
- Suggested packages: `com.technotes.notes.config`, `security`, `category`, `note`, `revision`, `common.error`, `common.validation`. Each feature contains controller, request/response DTOs, service and repository as needed. Never expose MongoDB documents as HTTP DTOs.
- Include `README.md`, this specification, Maven Wrapper, `application.yml`, `application-local.yml`, a `.env.example` containing placeholders, and a reproducible Docker Compose definition. These are files to implement, not files asserted to exist in the current repository.
- Explicitly apply MongoDB indexes through a documented migration/initializer; verify them in integration tests. Keep automatic schema/index changes controlled.

## 4. Shared authentication contract

Local issuer: **`http://localhost:9000`**. API Gateway: **`http://localhost:8080`**. Future React dev origin: **`http://localhost:5173`**. Keep the exact issuer string stable; container networking must not silently replace it with a different hostname.

Protected endpoints accept `Authorization: Bearer <access_token>`. Validate signature, approved signing algorithm, expiry, not-before, exact issuer and audience **`technotes-api`**. ID tokens are not API credentials. Read public keys from the issuer's JWKS. Unknown signing keys fail closed if they cannot be retrieved. Cached known keys may continue validating unexpired tokens during an issuer outage.

Claims agreed with User/OAuth Service:

```json
{
  "iss": "http://localhost:9000",
  "sub": "89a8150a-d5c2-4bfd-8f53-d77200e3a771",
  "aud": ["technotes-api"],
  "jti": "47eb0db4-f0c0-4766-9c31-4c01ed59bd80",
  "scope": "openid profile notes.read notes.write profile.read profile.write",
  "roles": ["AUTHOR"],
  "iat": 1790595000,
  "nbf": 1790595000,
  "exp": 1790595600
}
```

The timestamps above are illustrative. Normal access-token lifetime is a proposed **10 minutes**. Map scopes to `SCOPE_<scope>` and roles to `ROLE_<role>` explicitly. The project contract normalizes `scope` to a space-separated string. Roles do not replace scope checks; ADMIN still needs the endpoint's scope.

| Role | Notes rights, subject to scopes |
|---|---|
| READER | Public published notes; no protected authoring APIs |
| AUTHOR | Own draft create/read/list/update/delete and submit |
| REVIEWER | Read submitted notes, reject/publish another author's submission |
| ADMIN | Taxonomy administration, cross-author management and publishing |

For authenticated users without a required scope or role, return 403. With suitable role/scope but no access to a particular private note, return 404 to avoid disclosing its existence. Never trust `X-User-Id`, `X-Roles`, an `authorId` body field, or a caller's Gateway origin as authentication.

Scope vocabulary: `notes.read`, `notes.write`, `notes.review`, `taxonomy.write`. Public reads require no bearer token. Reviewer access does not include editing someone else's text.

## 5. Taxonomy and MongoDB model

**Decision proposed for this fresh baseline:** use one recursive `categories` collection. “Subcategory” and “topic” are UI labels for nodes in the same tree. There is no separate `/topics` API or `topics` collection in v1. This follows the Project HQ and Notes Company Standard, superseding earlier split category/topic drafts for this implementation.

### categories

| Field | Type / rule |
|---|---|
| `_id` | UUID string, generated by server |
| `name` | Trimmed string, 1–100 characters |
| `slug` | Lowercase ASCII slug, 1–100 characters; immutable after creation |
| `parentId` | UUID or null for root |
| `ancestorIds` | Ordered root-to-parent UUID list; computed by server |
| `level` | Root=1; proposed maximum depth=8 |
| `description` | Optional string, maximum 1,000 characters |
| `active` | Boolean; default true |
| `sortOrder` | Integer 0–100000; default 0 |
| `version` | Optimistic-lock counter, initial value 0 |
| audit fields | `createdAt`, `updatedAt`, `createdBy`, `updatedBy` |

Indexes: unique `{parentId:1, slug:1}`, and `{parentId:1, active:1, sortOrder:1, _id:1}`. Normalize all root `parentId` values to null so root uniqueness is consistent. Parent must exist and the entire ancestor chain must be active. Parent moves are excluded from v1, preventing concurrent reparenting/cycle complexity. Name/description/sortOrder/active can change; slug and parentId cannot. A node is effectively inactive if any ancestor is inactive.

### notes — M1

| Field | Type / rule |
|---|---|
| `_id` | UUID string, generated by server |
| `title` | Trimmed string, 1–200 characters |
| `slug` | Server-generated stable slug with ID suffix; globally unique and immutable |
| `summary` | Optional string, maximum 500 characters |
| `contentMarkdown` | Required nonblank string, maximum 1 MiB UTF-8 |
| `primaryCategoryId` | Required existing active category UUID |
| `tags` | Up to 10 unique lowercase slugs, 1–40 characters each |
| `contentKind` | `NOTE`, assigned by server |
| `authorId` | Verified access-token `sub`; immutable |
| `status` | `DRAFT` in M1; editorial states introduced in M2 |
| `visibility` | `PRIVATE` default; `PUBLIC` permitted but invisible until publication |
| `version` | Optimistic-lock counter, initial 0 |
| `deletedAt` | Null or soft-delete timestamp; deleted notes excluded from normal queries |
| audit fields | `createdAt`, `updatedAt`, `createdBy`, `updatedBy` |

Use `primaryCategoryId` consistently in DTOs, database and tests; previous drafts used `categoryId`. Do not silently accept both. Examples use string UUIDs, not MongoDB ObjectId parsing. Do not store derived category paths in notes in M1; resolve breadcrumbs from category IDs.

Indexes: unique `{slug:1}`; owner listing `{authorId:1, deletedAt:1, status:1, updatedAt:-1, _id:-1}`. Add category listing indexes after the relevant query exists and its query plan is checked. Test duplicate-key behavior; a controller pre-check does not enforce uniqueness under concurrency.

### M2 publication storage

Use `note_revisions` with unique `{noteId:1, revisionNumber:1}` and immutable publication snapshots containing title, slug, summary, Markdown, primary category, tags, visibility, author and reviewer IDs, and publication timestamp. Keep `publishedRevisionId` plus the published listing projection in the note. A new draft never overwrites the last published snapshot.

Publication updates the revision and published pointer atomically in a MongoDB transaction, requiring a local/test replica set. If this is not ready, the publication API remains unavailable. Public pagination filters the published projection, not mutable draft fields. Create public listing indexes for `publicVisible`, published category and publication time once M2 implements them.

## 6. API conventions

- Gateway URLs preserve the paths below. Business endpoints use JSON. Dates are UTC ISO-8601; IDs are opaque UUID strings.
- Maximum JSON request body: proposed 2 MiB; oversized requests return 413. Do not return stack traces, note bodies, tokens or database details in logs/errors.
- Single-resource success returns the DTO directly. Create returns 201 plus `Location` and `ETag`; GET/PATCH return 200 plus `ETag`; delete returns 204 without a body.
- Notes ETag format: `"note-<uuid>-v<version>"`; categories: `"category-<uuid>-v<version>"`. Mutations to an existing resource require `If-Match`. Missing header → 428; stale version → 412. Use an atomic version condition/optimistic locking, not read-then-save without a guard.
- PATCH uses a documented partial JSON object, not JSON Patch operations. Omitted fields stay unchanged; null is allowed only for `summary` or category `description` to clear them. Empty tag array clears tags. Unknown/server-owned fields return 400.
- Pagination: zero-based `page`, default `size=20`, max 100. Allow only the documented sort fields; add ID as a stable tie-breaker. Reject invalid enum/filter/sort values with 400.
- List projection excludes Markdown. No unbounded list/tree endpoints.

Common application error contract (also used by User/OAuth business APIs):

```json
{
  "timestamp": "2026-09-28T12:00:00Z",
  "status": 400,
  "code": "VALIDATION_FAILED",
  "message": "Request validation failed",
  "path": "/api/v1/notes",
  "traceId": "example-trace-id",
  "fieldErrors": [{"field": "title", "message": "must not be blank"}]
}
```

Codes include `VALIDATION_FAILED` (400), `UNAUTHENTICATED` (401), `FORBIDDEN` (403), `NOTE_NOT_FOUND` (404), `CATEGORY_NOT_FOUND` (404), `INVALID_STATE`/`DUPLICATE_SLUG`/`CATEGORY_IN_USE` (409), `VERSION_CONFLICT` (412), `PAYLOAD_TOO_LARGE` (413), `PRECONDITION_REQUIRED` (428), `RATE_LIMITED` (429) and `DEPENDENCY_UNAVAILABLE` (503). Authentication errors include the appropriate `WWW-Authenticate` header. Infrastructure responses may not carry the application JSON body.

## 7. Endpoint catalogue

All protected endpoints require a valid user access token. “Own” means `authorId == sub`; ADMIN may manage any note when scope permits.

| Stage | Method and path | Permission | Success |
|---|---|---|---|
| M1 | POST `/api/v1/categories` | ADMIN + taxonomy.write | 201 Category DTO |
| M1 | GET `/api/v1/categories` | AUTHOR/REVIEWER/ADMIN + notes.read | 200 paginated nodes |
| M1 | GET `/api/v1/categories/{id}` | Same as above | 200 Category DTO |
| M1 | PATCH `/api/v1/categories/{id}` | ADMIN + taxonomy.write; If-Match | 200 Category DTO |
| M1 | POST `/api/v1/notes` | AUTHOR/ADMIN + notes.write | 201 Note DTO |
| M1 | GET `/api/v1/notes` | AUTHOR/REVIEWER/ADMIN + notes.read | 200 scoped page |
| M1 | GET `/api/v1/notes/{id}` | Owner/ADMIN; reviewer rule in M2; notes.read | 200 Note DTO |
| M1 | PATCH `/api/v1/notes/{id}` | Owner AUTHOR/ADMIN + notes.write; draft only; If-Match | 200 Note DTO |
| M1 | DELETE `/api/v1/notes/{id}` | Owner AUTHOR/ADMIN + notes.write; draft only; If-Match | 204 soft-deleted |
| M2 | POST `/api/v1/notes/{id}/submit` | Owner AUTHOR/ADMIN + notes.write; If-Match | 200 Note DTO |
| M2 | POST `/api/v1/notes/{id}/reject` | REVIEWER/ADMIN + notes.review; If-Match | 200 Note DTO |
| M2 | POST `/api/v1/notes/{id}/publish` | REVIEWER/ADMIN + notes.review; If-Match | 200 Note DTO |
| M2 | POST `/api/v1/notes/{id}/draft` | Owner AUTHOR/ADMIN + notes.write; If-Match | 200 working draft |
| M2 | POST `/api/v1/notes/{id}/archive` | Owner AUTHOR/ADMIN + notes.write; If-Match | 200 Note DTO |
| M2 | GET `/api/v1/notes/{id}/revisions` | Owner/ADMIN or assigned-review-context REVIEWER + notes.read | 200 paginated revision metadata |
| M2 | GET `/api/v1/notes/{id}/revisions/{revisionId}` | Same visibility rule as above | 200 snapshot |
| M2 | GET `/api/v1/public/notes` | Anonymous; published PUBLIC only | 200 public page |
| M2 | GET `/api/v1/public/notes/{slug}` | Anonymous; published PUBLIC only | 200 published snapshot |
| M2 | GET `/api/v1/public/categories` | Anonymous; effectively active nodes only | 200 paginated nodes |
| B0 | GET `/actuator/health` | Local/internal | 200 or 503 health |

Do not expose category deletion or reparenting in v1. Deactivation is through PATCH. Do not implement a free-form status update through PATCH.

### 7.1 Category request/response

POST `/api/v1/categories`:

```json
{
  "name": "Collections",
  "slug": "collections",
  "parentId": "9a4fd205-f18d-4b28-b086-a0b75aa8a8fd",
  "description": "Java collection framework",
  "sortOrder": 10
}
```

Response includes these fields plus `id`, `ancestorIds`, `level`, `active`, `version`, `createdAt`, `updatedAt`. Root creation sends `parentId:null`. Validate slug pattern `[a-z0-9]+(?:-[a-z0-9]+)*`. Conflict → 409; absent parent → 404; depth or inactive-parent violation → 400.

Category list: `?parentId=<uuid>&page=0&size=20&sort=sortOrder,asc`; `rootOnly=true` selects roots and cannot be combined with `parentId`. Without either, return a paginated flat list. `active=false` or `includeInactive=true` is ADMIN-only. Load child pages lazily in the UI. Public category list uses the same parent/root selectors, but never accepts includeInactive.

PATCH category accepts only `name`, `description`, `active`, `sortOrder`. Deactivation is rejected with 409 if the node/subtree has a live public publication; archive or recategorize those publications first. Internal drafts may remain but cannot be submitted/published while their category ancestry is inactive.

### 7.2 Create draft note

POST `/api/v1/notes`:

```json
{
  "title": "ArrayList internals",
  "summary": "Capacity, resizing and iteration",
  "contentMarkdown": "# ArrayList\n\n```java\nList<String> names = new ArrayList<>();\n```",
  "primaryCategoryId": "6c4d7658-82e1-494f-b333-3d0b063cb5d2",
  "tags": ["java", "collections"],
  "visibility": "PRIVATE"
}
```

201 response:

```json
{
  "id": "f6b32588-4f11-4615-b201-4ac408b6dca4",
  "title": "ArrayList internals",
  "slug": "arraylist-internals-f6b32588",
  "summary": "Capacity, resizing and iteration",
  "contentMarkdown": "# ArrayList\n\n```java\nList<String> names = new ArrayList<>();\n```",
  "primaryCategoryId": "6c4d7658-82e1-494f-b333-3d0b063cb5d2",
  "tags": ["java", "collections"],
  "contentKind": "NOTE",
  "authorId": "89a8150a-d5c2-4bfd-8f53-d77200e3a771",
  "status": "DRAFT",
  "visibility": "PRIVATE",
  "version": 0,
  "createdAt": "2026-09-28T12:00:00Z",
  "updatedAt": "2026-09-28T12:00:00Z"
}
```

`Location: /api/v1/notes/f6b32588-4f11-4615-b201-4ac408b6dca4`  
`ETag: "note-f6b32588-4f11-4615-b201-4ac408b6dca4-v0"`

409 on slug collision; retry generation internally with a longer suffix before exposing failure. Creating a note in a missing/inactive category is rejected. POST is not inherently idempotent; the UI must avoid blind retries after an unknown result. Idempotency keys are a later enhancement.

### 7.3 Read, list, edit and delete

Protected GET by ID returns the editable DTO. A foreign private note, a deleted note or unknown ID returns 404. Query authorization in the repository/service layer; do not fetch an unfiltered page and remove unauthorized rows afterward.

List: `GET /api/v1/notes?page=0&size=20&status=DRAFT&sort=updatedAt,desc`. Optional filters: `primaryCategoryId`, single `tag`, and `view=mine|review|all`. Default `mine` always filters `authorId=sub`; `review` is M2 REVIEWER/ADMIN-only and filters IN_REVIEW; `all` is ADMIN-only. `sort` accepts updatedAt or createdAt, asc/desc. M1 accepts only status DRAFT. Category filter means exact node; subtree search is deferred.

```json
{
  "items": [{"id": "f6b32588-4f11-4615-b201-4ac408b6dca4", "title": "ArrayList internals", "slug": "arraylist-internals-f6b32588", "summary": "Capacity, resizing and iteration", "primaryCategoryId": "6c4d7658-82e1-494f-b333-3d0b063cb5d2", "tags": ["java", "collections"], "status": "DRAFT", "visibility": "PRIVATE", "version": 0, "updatedAt": "2026-09-28T12:00:00Z"}],
  "page": 0,
  "size": 20,
  "totalElements": 1,
  "totalPages": 1
}
```

PATCH accepts title, summary, contentMarkdown, primaryCategoryId, tags and visibility. It requires the ETag from the latest read, increments version, preserves slug and author, and returns the new ETag. In M2 it edits the working draft only. Status IN_REVIEW is locked against editing until rejection; PUBLISHED requires the explicit draft action first.

DELETE soft-deletes a DRAFT without any existing published revision. Attempting to delete a note with a public/private publication returns 409; archive it instead in M2. Subsequent normal GET returns 404; repeated DELETE after deletion returns 404. Soft-delete never releases the unique slug for reuse.

### 7.4 M2 publication and public reading

Lifecycle: DRAFT → IN_REVIEW → PUBLISHED → ARCHIVED. Rejection returns IN_REVIEW → DRAFT. `POST .../draft` allows PUBLISHED → DRAFT by copying the published snapshot into a working draft while keeping the previous publication visible.

- submit: no body; validate nonblank content, active category ancestry, the persisted author ID and allowed metadata. No synchronous User database lookup is required; account deactivation follows the shared token-lifetime policy.
- reject: `{"reason":"Please add a resizing example"}`; reason 1–1000 characters; persist reviewer audit.
- publish: no body; IN_REVIEW only; a REVIEWER cannot approve their own note; ADMIN may explicitly approve with an audit record. Make immutable snapshot and published pointer/projection update in one transaction. New snapshot visibility decides anonymous access.
- archive: `{"reason":"Outdated content"}` with optional reason up to 1000 characters; permitted for any nondeleted note. Set ARCHIVED and disable public visibility atomically. Restoration is deferred.
- All actions require If-Match and increment the note version. Invalid transitions → 409. Stale version → 412.
- Public list supports page/size, exact primaryCategoryId, one tag and `sort=publishedAt,desc|asc`; list summaries come from the latest published snapshot. Detail lookup is by immutable slug only and returns the snapshot plus revisionNumber and publishedAt; omit internal reviewer/audit/security fields.
- Public details and lists never return draft changes, PRIVATE publications, archived/deleted notes or inaccessible-category publications. Any public filtering change must be tested for both detail and list endpoints. A hidden result returns 404, not a login redirect.
- Revisions list returns revisionNumber, publication timestamp and revisionId; detail returns snapshot. Reviewer access is limited to a note currently IN_REVIEW; it must not become general access to all private history.

## 8. Attachments, blogging and interview content

No upload endpoint is implemented in M1/M2. Later, Media Service issues attachment IDs after MIME/size/ownership validation. Notes stores references and verifies association permissions. Markdown may use a documented `asset://<attachment-id>` scheme only after rendering support exists; reject it in M1 rather than creating broken content. External Markdown images must pass the eventual renderer's URL policy; raw HTML is disabled/sanitized in UI rendering.

BLOG and INTERVIEW_QUESTION will be separate validated content schemas or explicitly versioned DTO variants. Do not add arbitrary question/answer/difficulty fields to the initial note request. Kafka, search, outbox and binary storage need their own design before implementation.

## 9. Local setup contract and developer checklist

Target environment variables:

```dotenv
SERVER_PORT=8081
MONGODB_URI=mongodb://localhost:27018/technotes_notes_db
OAUTH_ISSUER_URI=http://localhost:9000
OAUTH_JWK_SET_URI=http://localhost:9000/oauth2/jwks
OAUTH_AUDIENCE=technotes-api
EUREKA_URL=http://localhost:8761/eureka/
CONFIG_SERVER_URL=http://localhost:8888
```

These are agreed environment names that the baseline must bind, not automatically recognized Spring settings. Map them to Spring configuration and explicit audience validation. Use loopback for directly exposed local services. Keep credentials out of Git; the illustrative local Mongo URI has no credentials and must not become a deployed configuration.

In IntelliJ: set Project SDK and Maven runner JDK to 21; use Maven Wrapper; activate local profile. From PowerShell in the repository:

```powershell
.\mvnw.cmd clean verify
.\mvnw.cmd spring-boot:run "-Dspring-boot.run.profiles=local"
```

Run MongoDB first, then User/OAuth Service, then Notes. Add Eureka/Config/Gateway when the shared infrastructure configuration is ready. On a 16 GB laptop start only required containers; Kafka, Kubernetes, Jenkins and Elasticsearch are not baseline prerequisites. An isolated `test` profile may use test keys/JWT support, never a production bypass.

## 10. Testing and Definition of Done

1. Fresh clone compiles with Java 21 and Maven Wrapper; health reflects Mongo connectivity. No test that excludes Mongo is counted as persistence proof.
2. Testcontainers verifies saving/reloading note content, unique indexes, category queries, soft-delete filtering and optimistic concurrency against real MongoDB.
3. HTTP tests cover 201/Location/ETag, pagination, DTO validation, 400/401/403/404/409/412/413/428 and no server-field injection.
4. Verify author A cannot read/edit author B's private draft; READER cannot create; REVIEWER cannot edit another author's text. Cover both list and detail queries.
5. Reject wrong issuer/audience, expired token, wrong signature and ID token used as an API token. A scope without the required role is insufficient.
6. Integration: obtain a real access token from Shakti's issuer, call Gateway → Notes, save to MongoDB, read back, and test a disallowed identity. Neither mocked authentication nor a 200 health response counts as this integration.
7. M2 adds transactional publication, stable published snapshots during edits, reviewer self-approval prevention and public privacy tests before enabling public routes.
8. PR includes updated API examples, test results, configuration documentation and reviewer approval. Logs contain trace ID, route, status and duration, not tokens/passwords/note text.

## 11. Handoff to Shakti and Git workflow

Developer 2 supplies the finalized category/note DTOs, error examples, service health, test results and any contract change. Shakti supplies a local issuer, registered test client, test identities with roles and the shared claims contract. No real credentials are committed or pasted into Jira.

After documentation review, create baseline and Mongo/domain tickets. Branch convention: `feature/<actual-jira-key>-notes-baseline`, followed by `feature/<actual-jira-key>-notes-domain`. The angle-bracket value is a placeholder; do not create a fake ticket key. One ticket → one branch → reviewed PR into develop. Existing source should be inspected before a reviewed baseline replacement; do not force-push or discard local uncommitted work as part of following this document.

## 12. Sources and decision status

Project requirements were reconciled from `TechNotes_Project_HQ_Master_v1.docx` and `TechNotes_Notes_Service_Company_Standard_v1.docx`, read on 2026-09-28. Earlier Jira snapshots in those documents are historical; the new project and tickets are not asserted to exist.

Primary technical reference: [Spring Security JWT Resource Server](https://docs.spring.io/spring-security/reference/servlet/oauth2/resource-server/jwt.html). Use the version matching the pinned Boot/Security stack when coding; current reference examples can target a newer Spring generation.

The concrete field limits, ports, audience, scope vocabulary, API paths, phase split, storage shape and concurrency/publication policies above are TechNotes design proposals. They form a consistent starting contract for review, not a claim of completed code or approved production readiness. Owner assignment follows Shakti's latest instruction.
