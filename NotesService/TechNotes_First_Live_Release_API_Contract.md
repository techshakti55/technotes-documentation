# TechNotes first live release — exact API contract

**29 Sep 2026 | Backend implementers: Shakti (User/OAuth), Developer 2 (Notes)**  
**Status:** UI integration contract; service behavior must be implemented and tested. Paths are Gateway-visible. OAuth issuer protocol paths stay at the issuer origin.

## Shared conventions

- Local React `http://localhost:5173`, Gateway `http://localhost:8080`, issuer `http://localhost:9000`. AWS equivalents must use HTTPS and exact configured origins.
- Business IDs are UUID strings; timestamps ISO-8601 UTC. Protected calls use `Authorization: Bearer <access_token>`; audience `technotes-api`.
- JSON single-resource responses are **direct objects** (no `{data:...}` wrapper). List response: `{"items":[],"page":0,"size":20,"totalElements":0,"totalPages":0}`. UI requests up to 100 per page; backend max 100.
- `Content-Type: application/json`; CORS permits actual browser origin and Authorization/Content-Type/If-Match headers, GET/POST/PATCH/OPTIONS, and exposes ETag/Location. API Gateway must not strip bearer token, ETag or If-Match.
- Error body: `{"timestamp":"...","status":400,"code":"VALIDATION_FAILED","message":"...","path":"...","traceId":"...","fieldErrors":[]}`. 401 invalid/missing token; 403 insufficient scope/role; 404 unknown/inaccessible; 409 invalid state; 412 stale ETag; 428 missing If-Match; 503 unavailable.

## Page 1 — User/OAuth Service (Shakti)

| Method and issuer/Gateway path | Request | Response / UI use |
|---|---|---|
| GET `http://localhost:9000/oauth2/authorize` | Query `response_type=code`, `client_id=technotes-web`, `redirect_uri=http://localhost:5173/auth/callback`, `scope=openid profile notes.read notes.write notes.review taxonomy.write profile.read`, `state`, `nonce`, `code_challenge`, `code_challenge_method=S256` | Browser login/consent redirects with `code` and original `state`. Framework-owned, not custom JSON. |
| POST `http://localhost:9000/oauth2/token` | `application/x-www-form-urlencoded`: `grant_type=authorization_code`, `client_id`, `code`, exact `redirect_uri`, `code_verifier` | `{"access_token":"...","token_type":"Bearer","expires_in":600,...}`. Public client, no client secret in UI. Issuer CORS allows browser origin. |
| GET `http://localhost:9000/oauth2/jwks` | Public | JWK Set with public signing keys; Notes validates access token. |
| GET `/api/v1/users/me` via Gateway | Bearer + `profile.read` | 200 direct object `{"id":"uuid","displayName":"Shakti Singh","email":"...","roles":["ADMIN"],"status":"ACTIVE"}`; UI displays owner workspace. |

Provision the owner account privately. Public signup is not needed today. Token claims: `iss` exact issuer; `sub` immutable user UUID; `aud=["technotes-api"]`; space-separated `scope`; `roles=["ADMIN"]` (AUTHOR too if policy requires); `iat`, `nbf`, `exp`. Issue `taxonomy.write`, `notes.read`, `notes.write`, `notes.review`, `profile.read` to this account. Use persistent PostgreSQL OAuth state and stable signing key so restart does not invalidate all unexpired tokens.

**Required integration:** client redirect and Web origin are exact, code+PKCE S256 works, authorization code cannot be replayed, token endpoint CORS works, bad audience/issuer tokens fail in Notes. Do not put password login or private client secret in React.

## Page 2 — Notes Service (Developer 2)

**Public endpoints, no bearer required:**

| Method and Gateway path | Query / input | 200 response and rule |
|---|---|---|
| GET `/api/v1/public/categories` | `rootOnly=true&page=0&size=100` or `parentId=<uuid>&page=0&size=100` | Page of `CategoryResponse`: `id,name,slug,parentId,ancestorIds,level,active,sortOrder,version,createdAt,updatedAt`. Only effectively active nodes. UI initially uses root list. |
| GET `/api/v1/public/notes` | `page=0&size=100&sort=publishedAt,desc`; optional `primaryCategoryId=<uuid>` | Page of cards: `id,slug,title,summary,primaryCategoryId,categoryName,tags,publishedAt`. Exact category match; never include Markdown or drafts. |
| GET `/api/v1/public/notes/{slug}` | Stable slug | Published snapshot: `id,slug,title,summary,contentMarkdown,primaryCategoryId,categoryName,tags,revisionNumber,publishedAt`. 404 for absent, draft, PRIVATE, archived or deleted. |

**Protected endpoints (bearer required):**

| Method and Gateway path | Request | Response / rule |
|---|---|---|
| POST `/api/v1/categories` | `{"name":"Core Java","slug":"core-java","parentId":null,"sortOrder":0}`; ADMIN + taxonomy.write | 201 `CategoryResponse` + Location/ETag. UI creates root categories. |
| GET `/api/v1/notes?view=mine&page=0&size=100&sort=updatedAt,desc` | ADMIN/AUTHOR + notes.read | Page of own `NoteListItemResponse`: `id,title,slug,summary,primaryCategoryId,tags,status,visibility,version,updatedAt`; no body. |
| GET `/api/v1/notes/{id}` | Owner/ADMIN + notes.read | `NoteResponse` direct object plus `ETag: "note-<uuid>-v<N>"`; includes editable `contentMarkdown`. |
| POST `/api/v1/notes` | `{"title":"ArrayList internals","summary":"...","contentMarkdown":"# ...","primaryCategoryId":"uuid","tags":["java"],"visibility":"PUBLIC"}`; AUTHOR/ADMIN + notes.write | 201 `NoteResponse`, Location and ETag. Server sets `id,slug,authorId=sub,contentKind=NOTE,status=DRAFT,version=0`, timestamps. PUBLIC does **not** expose draft. |
| PATCH `/api/v1/notes/{id}` | Above editable fields + `If-Match` | 200 updated `NoteResponse` + new ETag. Draft only; title/summary/content/category/tags/visibility can change; omitted fields unchanged. |
| POST `/api/v1/notes/{id}/submit` | No JSON body + `If-Match`; owner + notes.write | 200 `NoteResponse` status `IN_REVIEW` + new ETag. |
| POST `/api/v1/notes/{id}/publish` | No JSON body + `If-Match`; ADMIN + notes.review in this owner-only phase | 200 `NoteResponse` status `PUBLISHED` + new ETag. Atomically create immutable revision and published pointer; allow explicit audited ADMIN self-publish exception **only after contract review**. |

`NoteResponse` fields: `id,title,slug,summary,contentMarkdown,primaryCategoryId,tags,contentKind,authorId,status,visibility,version,createdAt,updatedAt`. UI expects response after every mutation and does not invent a status locally. Note list and category list use the page envelope above. `visibility=PUBLIC` and published status are both required for anonymous read. Existing Notes v1 spec defines these routes except the extra `categoryName` convenience field and owner-only ADMIN self-publish exception; implement them explicitly or update UI + contract together.

**Minimum publish sequence:** create category → create draft → optionally PATCH → submit → publish → public list/detail reads snapshot. MongoDB transaction needs replica set. If publication transaction is not implemented, do not expose a misleading publish button/API. Test no draft leak, self-publish audit, ETag 428/412 and owner isolation.
