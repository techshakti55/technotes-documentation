# TechNotes.co.in — Backend Product Blueprint v2

**Date:** 29 September 2026  
**Status:** Product direction agreed; implementation contracts for new capabilities remain proposed  
**Audience:** Backend developers, UI developers, product owner, reviewers

## 1. What we are building

TechNotes is a structured Java and DSA learning website with technical notes, code examples, interview question-and-answer content, community blogs and a single Premium subscription. Visitors can discover and read selected public material; registered free users gain more content and can submit blogs; subscribers access Premium learning material. Authors and reviewers manage the official learning library.

This document describes the **target product**, not a claim that every service or endpoint exists today. `Existing specification` means a design has been written, not that code has been verified. Before marking anything `Implemented`, inspect the relevant repository and run its acceptance checks.

### Product decisions from the 29 September discussion

- Three content access tiers: `PUBLIC`, `FREE_ACCOUNT`, `PREMIUM`.
- One Premium plan at launch; billing interval, price and provider are open.
- Blogging is a separate capability from curated Notes. Logged-in users can draft and submit blogs; review is required before publication.
- Visitors see meaningful content without login. Login unlocks additional free material. Premium unlocks paid material.
- Presentation material follows these backend and UI blueprints later.

## 2. Actors, roles and entitlement

| Actor | Intended capability |
|---|---|
| Anonymous visitor | Browse public taxonomy, public notes, published public Q&A and blogs; see previews of restricted material. |
| Registered free user (`READER`) | Public plus `FREE_ACCOUNT` content; own profile and reading list; create and manage own blog drafts and submit for review. |
| Active subscriber | All registered rights plus `PREMIUM` content while entitlement is valid. This is an entitlement, **not** a permanent identity role. |
| Curated-content `AUTHOR` | Create and edit own official note drafts; submit for editorial review. |
| `REVIEWER` | Review official content and community blog submissions under separate policies. |
| `ADMIN` | Manage taxonomy, editorial assignments, users and product configuration within audited permissions. |

The existing OAuth spec defines `READER`, `AUTHOR`, `REVIEWER`, `ADMIN` and scopes. Blog permissions and Premium entitlement require new contracts. No user may obtain editorial roles by self-registration. An author may also subscribe; role and entitlement are independent.

## 3. Target service landscape

| Component | Owns | Data / integration | Delivery status |
|---|---|---|---|
| API Gateway | API routing, edge CORS, request correlation and coarse controls | No business database | Core platform; verify repository state |
| User/OAuth Service | Accounts, profiles, roles, OAuth2/OIDC, signing keys and access tokens | PostgreSQL; existing proposed spec | Core |
| Notes Service | Recursive categories, curated notes, ownership, editorial lifecycle and immutable revisions | MongoDB; existing proposed spec | Core |
| Blog Service | Community blog drafts, author ownership, moderation, public publication and revisions | Own persistence; MongoDB proposed, to decide | New product service, design pending |
| Subscription/Billing Service | One plan, subscription lifecycle, provider event reconciliation and entitlement decisions | Own PostgreSQL proposed; external payment provider | New product service, design pending |
| Search Service | Unified discovery index over published notes, Q&A and blogs | Rebuildable search index; no source-of-truth ownership | Later |
| Media Service | Secure upload and metadata for content images or PDFs | Metadata plus object storage | Later, before user uploads |
| Notification capability | Review outcomes, billing and account messages | Email provider and/or later event consumer | Later; define minimal required email in owning services first |
| Config Server / Eureka | Central configuration / service discovery | Platform infrastructure, no business data | Core platform; verify repository state |

**Interview Q&A:** Start with a reviewed content type in the curated-content domain when its fields and editorial rules fit. A distinct Interview Service is a later option only if assessments, question banks, progress or specialized workflows justify its own boundary. Do not expose `INTERVIEW_QUESTION` through the present Notes v1 API: that spec explicitly reserves it for M3. **Payment:** Integrate the provider inside Subscription/Billing first; a separate Payment Service is not justified by the current requirements.

No service reads another service's database. Service-to-service APIs and events carry only needed data. Notes remains authoritative for curated content, Blog for user blogs, Subscription for entitlements.

## 4. Content model and access policy

Keep four concepts distinct:

| Concept | Example | Rule |
|---|---|---|
| Kind | NOTE, INTERVIEW_QA, BLOG | Different editorial ownership and presentation. |
| Lifecycle | DRAFT, IN_REVIEW, PUBLISHED, ARCHIVED | Governs whether a published snapshot exists. |
| Audience | PUBLIC, FREE_ACCOUNT, PREMIUM | Governs who may read a published snapshot. |
| Visibility/ownership | Private working copy vs published copy | A draft must never leak through a public list or cached response. |

The existing Notes v1 spec defines `visibility=PRIVATE/PUBLIC`, with `contentKind=NOTE` only in M1. **Do not silently rename that field or make `PREMIUM` an accepted v1 value.** Introduce a versioned access policy migration before paid launch: decide whether `visibility` remains an editorial flag and `accessTier` is a new field, migrate existing publications, revise DTOs/indexes, and test every endpoint. For v1/M1, keep the current draft contract unchanged. The more recent Notes spec uses one recursive `categories` collection; its UI labels may be category/subcategory/topic. The older technical design's separate `topics` collection conflicts with it and should be marked superseded for new implementation, subject to team review.

### Authorization order for a read

1. Resolve the published snapshot and audience without exposing unpublished text.
2. For `PUBLIC`, allow anonymous reads.
3. For `FREE_ACCOUNT`, require a valid access token.
4. For `PREMIUM`, require a valid user token and a current positive entitlement from Subscription/Billing.
5. Apply any additional account/content restrictions; return a safe preview or access response without premium body text.

The server enforces this policy on both detail and list APIs. Search documents, snippets, cached responses, media URLs and previews must respect the same rule. A missing entitlement service must fail closed for Premium bodies; the response design and short-lived entitlement cache policy are open decisions. Token roles alone must not claim payment status. Decide upgrade/downgrade timing, refund behavior, trial policy and grace period before billing release.

## 5. End-to-end workflows

### 5.1 Public discovery and login

Visitor opens the home page → browses the category tree → opens a public note or Q&A → sees a useful preview for gated content → registers/signs in with OAuth2 Authorization Code + PKCE → returns to the intended item. Registration initially grants `READER`; it does not grant `AUTHOR` or `REVIEWER`. User/OAuth owns credentials and issues tokens; Gateway routes business requests; each resource service validates token and permissions.

### 5.2 Official note authoring

Admin creates taxonomy nodes → AUTHOR creates a private Markdown draft in Notes → updates own draft with version/ETag check → submits for review → REVIEWER rejects with feedback or publishes → Notes writes an immutable published snapshot → appropriate audience can read it. New edits do not overwrite the last public version. The current Notes spec's M1 is draft CRUD, M2 is review and publication. Public discovery depends on completing M2 or using explicitly reviewed seeded public content through the same publication rules.

### 5.3 Community blogging

Registered user creates a blog draft in Blog Service → saves and previews → submits → reviewer checks technical quality, plagiarism/abuse policy and formatting → rejects with reason or publishes → reader sees published snapshot → edits to a published blog go through a new review cycle while the previously published version stays visible. Ownership and moderation apply server-side. Decide whether subscriber-only blogs are allowed; recommendation for launch: **all approved community blogs are public**, while Premium remains curated learning content. No arbitrary HTML/script execution; render Markdown safely and limit links/uploads.

### 5.4 Premium checkout and read

Logged-in user selects one Premium plan → Subscription/Billing creates provider checkout session → provider sends signed webhook to the backend → service verifies authenticity and idempotently reconciles provider payment/subscription state → only then grants entitlement → user can read Premium published content. Never trust a browser success redirect alone. Duplicate, delayed, out-of-order and failed webhooks must not grant access incorrectly. Price, tax, invoices, cancellation, refunds, provider and legal/payment policies require a later reviewed billing specification.

### 5.5 Search and background processing

Initial navigation and category filtering can use source services. Later Search indexes only published, permitted metadata and routes clicks to authoritative APIs. Publication events can feed indexing and notifications after a reliable outbox and idempotent consumers are specified. Kafka is a later platform milestone, not required for the first learning release.

## 6. Backend-facing UI contracts to design

These are **contract needs**, not claims that routes are implemented:

| UI experience | Contract owner | Needed response / behavior |
|---|---|---|
| Home and category browse | Notes | Public category hierarchy, featured published cards, pagination and access tier label. |
| Note reader | Notes | Published snapshot, Markdown, breadcrumbs, previous/next, safe gated preview. |
| Login/profile | User/OAuth | PKCE redirect/callback, `/users/me`, session/error states. |
| Author workspace | Notes | Own draft list, create/edit, submit, revision/status feedback. |
| Review queue | Notes + Blog | Separate queues, explicit approve/reject actions and audit context. |
| Community blogs | Blog | Public feed/detail, own drafts, submit, moderation status and author attribution. |
| Subscription page | Subscription/Billing | Plan display, authenticated checkout session, subscription/entitlement status. |
| Interview prep | Notes curated-content extension | Question listing, answer detail, topic/difficulty filters and audience. |
| Reading list | To decide | User-owned saved content references; no separate service at launch unless needed. |
| Unified search | Search | Permission-aware hits and filters, with source-service recheck on opening. |

For each new endpoint, specify method/path, permissions, request/response examples, pagination, error cases, access-tier behavior and versioning. Use the existing Notes and User/OAuth specs as the authority for their present v1 contracts. Establish a shared error envelope and trace ID. Do not accept client-owned authorId, status, subscription state or payment confirmation as truth.

## 7. Delivery sequence and acceptance gates

| Phase | Product result | Backend gate |
|---|---|---|
| 0 — verify baseline | Known build/run state | Inspect core repositories; pin compatible dependencies, health, config, database and tests. |
| 1 — secure authoring | Login plus private official drafts | Real-token Gateway → Notes flow; two authors cannot read each other's drafts. |
| 2 — public learning | Anonymous notes and registered free content | Reviewed publication snapshots, taxonomy browsing, safe access-tier migration and public APIs. |
| 3 — community + interview | Blogs and interview Q&A | Blog moderation and ownership; reviewed Q&A model, public feed, safe Markdown. |
| 4 — Premium | One paid plan | Provider webhook verification, entitlement decisions, expiry/cancel tests, no content leakage. |
| 5 — discovery and scale | Search, media, notifications | Rebuildable index, secure uploads, reliable events where justified. |

Local integration should be reproducible with Docker Compose after each service builds independently. Use versioned images, externalized secrets, health checks and contract tests across Gateway, identity and content. CI/CD, cloud deployment and Kubernetes come after a stable containerized release; they are not proof of product functionality.

## 8. Decisions to record before tickets

1. Confirm one recursive category tree as the new Notes implementation contract; reconcile older topic schema documents.
2. Define public/free/Premium access migration and preview contract without breaking existing Notes v1 DTOs.
3. Choose Blog persistence and blog/reviewer permission scopes; decide review policy and revisions.
4. Choose how interview Q&A fits curated content and which fields differ from notes.
5. Define single Premium plan billing interval, price, provider, cancellation/refund rules and webhook contract.
6. Decide entitlement check freshness, outage response and secure cache invalidation.
7. Define search indexing of tiered content and media access before those features ship.
8. Verify actual repository state, ownership and deployment environment; never label planned APIs as implemented on the basis of documentation.

## 9. Source and change record

- `TechNotes_Notes_Service_Spec_v1.md` (28 Sep 2026): Notes M1/M2, recursive category model, security and API contract.
- `TechNotes_User_OAuth_Service_Spec_v1.md` (28 Sep 2026): identity, roles/scopes, OIDC/PKCE and user APIs.
- `TechNotes_Backend_Architecture_Blueprint_v1.docx`: earlier platform landscape and phased technical architecture.
- Owner discussion on 29 Sep 2026: anonymous/free/Premium content, one plan, separate community blogging, backend and UI documents before presentation.

**Scope rule:** New product flows in this v2 blueprint require their own reviewed API/data specifications before implementation. The existing v1 service specs remain authoritative for their currently defined endpoints.
