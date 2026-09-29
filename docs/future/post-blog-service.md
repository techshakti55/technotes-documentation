# TechNotes Post / Blog Service - Engineering Blueprint v1

**Date:** 29 September 2026 | **Status:** new proposed service specification; no existing endpoint is claimed implemented  
**Product owner:** Shakti Singh | **Dependency:** User/OAuth identity; separate from curated Notes Service

## 1. Meaning and ownership

“Post Service” here means the community **Blog/Post Service** requested in the product discussion. A registered user can write a technical blog, save drafts and submit for review. A reviewer can reject with feedback or publish. Readers see only approved published versions. This service owns post text, moderation state, author IDs, revisions, tags and its own persistence. Notes owns official curated lessons and category taxonomy; Blog may reference a public category ID through a reviewed integration but must not read Notes MongoDB. Subscription is not required for blogging in the first release; approved community posts are public.

## 2. Product workflow

`DRAFT → IN_REVIEW → PUBLISHED`; rejection `IN_REVIEW → DRAFT` with feedback; editing a published post creates a new working draft while its previous approved snapshot remains public; `PUBLISHED → ARCHIVED` removes it from listings. A user may edit/delete only their own unpublished draft. Reviewer cannot silently rewrite another author's body; review actions are audited. Decide self-approval policy (recommend prohibit even when a reviewer also owns the post; explicit ADMIN override audited). Abuse reporting and takedown policy are follow-up work before large-scale public submissions.

## 3. Architecture and dependencies

React → Gateway → Blog Service → its own MongoDB (proposed). Blog validates JWT using User/OAuth issuer/JWKS; no credential storage. Blog may validate category reference through Notes' published taxonomy API or use a synchronized read projection after contract review. Do not make a synchronous Notes dependency mandatory for saving draft text; validate category at submission/publish. Search later indexes published public post snapshots through reliable events/outbox. Media later owns uploads. No direct payment integration.

Suggested dependencies: Java 21, pinned Spring Boot/Cloud, Spring MVC, Data MongoDB, Validation, OAuth2 Resource Server, Actuator, OpenAPI, JUnit, Testcontainers. Use Java/Maven Wrapper and consistent profiles/error format with Notes. Choose DB and ports with team before implementation; do **not** assume Notes' Mongo database or port 8081 can be reused.

## 4. Proposed domain model

| Collection | Core fields and rules |
|---|---|
| `posts` | UUID `id`, immutable slug, title 1–200, summary ≤500, Markdown ≤1 MiB, authorId from JWT `sub`, tags ≤10, optional primaryCategoryId, status, version, deletedAt, audit fields, publishedRevisionId and published projection. |
| `post_revisions` | Immutable approved snapshots, revisionNumber, publishedAt, reviewedBy, title/summary/body/tags/category, unique postId+revisionNumber. |
| `post_reviews` or audit collection | Submission ID, reviewer ID, action, reason, timestamp/trace; keep rejected feedback visible to owner. |

Unique slug index; owner/status/updatedAt listing index; public publishedAt listing index; review queue status/submittedAt index. Atomic publication snapshot/pointer needs Mongo replica set; if not available, keep publish disabled. Use version/ETag to reject lost updates. Effective public content is always the approved snapshot, never the mutable draft.

## 5. DTO and API proposal

| DTO | Fields / constraints |
|---|---|
| `CreatePostRequest` | title, summary?, contentMarkdown, tags[], primaryCategoryId?; no author/status/slugs/version supplied by caller. |
| `PatchPostRequest` | Optional title, summary, contentMarkdown, tags, category; omitted unchanged; null only clears summary/category if agreed. |
| `PostResponse` | id, slug, owner ID, editable fields, status, version, createdAt, updatedAt, last rejection feedback; protected owner view. |
| `PostCardResponse` | slug, title, summary, author public display, tags, publishedAt; no Markdown. |
| `PublishedPostResponse` | Approved snapshot body and metadata; excludes reviewer/security audit. |
| `ReviewPostRequest` | Reject reason required 1–1000; publish no body or reviewed metadata only. |
| `PageResponse<T>` / `ApiErrorResponse` | Follow shared paging and error envelope from Notes. |

| Method / path (proposed) | Actor | Purpose |
|---|---|---|
| POST `/api/v1/posts` | Logged-in READER+ `blogs.write` | Create own DRAFT |
| GET `/api/v1/posts/mine` | Owner + blogs.read | Paginated own drafts/status |
| GET `/api/v1/posts/{id}` | Owner / assigned reviewer / ADMIN | Protected working copy |
| PATCH `/api/v1/posts/{id}` | Owner + blogs.write + If-Match | Edit allowed draft |
| DELETE `/api/v1/posts/{id}` | Owner + blogs.write + If-Match | Soft-delete never-published draft |
| POST `/api/v1/posts/{id}/submit` | Owner + blogs.write + If-Match | Send for review |
| GET `/api/v1/posts/review-queue` | REVIEWER/ADMIN + blogs.review | Scoped queue |
| POST `/api/v1/posts/{id}/reject` | Reviewer + blogs.review + If-Match | Feedback and return to draft |
| POST `/api/v1/posts/{id}/publish` | Reviewer + blogs.review + If-Match | Create approved snapshot |
| POST `/api/v1/posts/{id}/draft` | Owner + blogs.write + If-Match | New version while prior stays live |
| POST `/api/v1/posts/{id}/archive` | Owner/ADMIN + authorized scope + If-Match | Remove public version |
| GET `/api/v1/public/posts` | Anonymous | Published public cards |
| GET `/api/v1/public/posts/{slug}` | Anonymous | Approved public body |

These routes are proposals and must get exact scopes, author display strategy, request/response examples, error mapping, moderation roles and category policy before tickets. Separate public paths from protected ID paths. Filter owner and reviewer queries in persistence layer; foreign private post returns 404. Public metadata and caches must never include unapproved Markdown. Lists are paginated, default 20/max 100; stable tie-breaker ID. If-Match missing 428, stale 412, invalid transition 409. Reject unknown/server-owned fields with 400.

## 6. Security and quality

Only authenticated users write; public users read approved posts. `sub` is authorId; never trust identity headers. Reviewer's authority requires both role and blogs.review scope. Sanitize rendered Markdown, disable raw HTML/scripts, apply link/image URL policy and size limits. Store no binary uploads in post documents. Control spam with signup/rate limits, submission quotas and moderation; add report/takedown flow before broad public growth. Do not expose private drafts in OpenGraph metadata/search snippets. Logging includes trace ID/status but no full user text or tokens.

## 7. Definition of Done and integration

Fresh clone runs with isolated DB/profile; Mongo/Testcontainers proves indexes and transactions; two users cannot read/edit each other's drafts; authenticated READER can submit; anonymous cannot write; reviewer can reject with feedback; self-approval blocked; old published version remains visible during new draft; public list/detail excludes rejected/deleted/archived working copies; wrong issuer/audience/expired token rejected; Gateway to Blog real-token test passes; UI editor, My Blogs, review queue and public detail consume documented examples.

Start after shared issuer contract and public product navigation are agreed. Build baseline → draft CRUD → moderation/snapshots → public feed → UI integration → search/media extension. Do not add the Blog `contentKind` to Notes M1 or share Notes' collections. Decisions still open: service name (`Blog Service` vs `Post Service`), own DB choice, exact port/repo, category reference, author display, scope names, moderation policy and published edit/takedown semantics.
