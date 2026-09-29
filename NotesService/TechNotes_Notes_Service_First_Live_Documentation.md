# TechNotes First Live Release — Notes Service Documentation

**Date:** 29 Sep 2026  
**Owner:** Developer 2  
**Service:** Notes Service  
**Database:** MongoDB  
**Gateway:** `http://localhost:8080`  
**Release Scope:** First live release only. Endpoint contract must remain unchanged.

---

## 1. Service Purpose

The Notes Service is responsible for:

- Maintaining the category hierarchy used by TechNotes.
- Creating and editing note drafts.
- Managing the note review/publish workflow.
- Serving anonymous public category and published-note APIs.
- Serving protected author/admin note-management APIs.
- Validating JWT access tokens issued by the User/OAuth Service.
- Deriving the note author from JWT `sub`.
- Preventing draft/private/archived/deleted content from leaking to public endpoints.
- Supporting optimistic concurrency with ETag / If-Match.
- Creating an immutable published snapshot during publication.

---

# 2. First Live Release Scope

## Public endpoints

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/v1/public/categories` | Read active category hierarchy |
| GET | `/api/v1/public/notes` | Read published public note cards |
| GET | `/api/v1/public/notes/{slug}` | Read one published public note |

## Protected endpoints

| Method | Path | Purpose |
|---|---|---|
| POST | `/api/v1/categories` | Create category |
| GET | `/api/v1/notes` | Read current user's note list |
| GET | `/api/v1/notes/{id}` | Read editable note |
| POST | `/api/v1/notes` | Create note draft |
| PATCH | `/api/v1/notes/{id}` | Update draft |
| POST | `/api/v1/notes/{id}/submit` | Submit draft for review |
| POST | `/api/v1/notes/{id}/publish` | Publish reviewed note |

No endpoint is to be renamed, removed, or added for today's first live release.

---

# 3. Proposed File Structure

> This structure is for implementation planning. Exact Java classes can be finalized during the DTO/document discussion, but the API contract remains unchanged.

```text
technotes-notes-service/
├── pom.xml
├── Dockerfile
├── src/
│   ├── main/
│   │   ├── java/com/technotes/notes/
│   │   │   ├── TechNotesNotesServiceApplication.java
│   │   │   │
│   │   │   ├── config/
│   │   │   │   ├── SecurityConfig.java
│   │   │   │   ├── MongoConfig.java
│   │   │   │   └── CorsConfig.java
│   │   │   │
│   │   │   ├── controller/
│   │   │   │   ├── PublicCategoryController.java
│   │   │   │   ├── PublicNoteController.java
│   │   │   │   ├── CategoryController.java
│   │   │   │   └── NoteController.java
│   │   │   │
│   │   │   ├── dto/
│   │   │   │   ├── category/
│   │   │   │   │   ├── CreateCategoryRequest.java
│   │   │   │   │   └── CategoryResponse.java
│   │   │   │   ├── note/
│   │   │   │   │   ├── CreateNoteRequest.java
│   │   │   │   │   ├── UpdateNoteRequest.java
│   │   │   │   │   ├── NoteResponse.java
│   │   │   │   │   ├── NoteListItemResponse.java
│   │   │   │   │   ├── PublicNoteCardResponse.java
│   │   │   │   │   └── PublicNoteDetailResponse.java
│   │   │   │   └── common/
│   │   │   │       ├── PageResponse.java
│   │   │   │       └── ApiError.java
│   │   │   │
│   │   │   ├── document/
│   │   │   │   ├── CategoryDocument.java
│   │   │   │   ├── NoteDocument.java
│   │   │   │   └── NoteRevisionDocument.java
│   │   │   │
│   │   │   ├── enums/
│   │   │   │   ├── NoteStatus.java
│   │   │   │   ├── Visibility.java
│   │   │   │   └── ContentKind.java
│   │   │   │
│   │   │   ├── repository/
│   │   │   │   ├── CategoryRepository.java
│   │   │   │   ├── NoteRepository.java
│   │   │   │   └── NoteRevisionRepository.java
│   │   │   │
│   │   │   ├── service/
│   │   │   │   ├── CategoryService.java
│   │   │   │   ├── NoteService.java
│   │   │   │   └── PublicationService.java
│   │   │   │
│   │   │   ├── security/
│   │   │   │   └── CurrentUserProvider.java
│   │   │   │
│   │   │   ├── mapper/
│   │   │   │   ├── CategoryMapper.java
│   │   │   │   └── NoteMapper.java
│   │   │   │
│   │   │   └── exception/
│   │   │       ├── GlobalExceptionHandler.java
│   │   │       ├── ResourceNotFoundException.java
│   │   │       ├── InvalidStateException.java
│   │   │       ├── MissingIfMatchException.java
│   │   │       └── StaleVersionException.java
│   │   │
│   │   └── resources/
│   │       ├── application.yml
│   │       └── application-local.yml
│   │
│   └── test/
│       └── java/com/technotes/notes/
│           ├── PublicCategoryControllerTest.java
│           ├── PublicNoteControllerTest.java
│           ├── CategoryControllerTest.java
│           ├── NoteControllerTest.java
│           └── PublicationFlowTest.java
```

---

# 4. Shared Notes-Service Rules

## 4.1 Authentication

Public endpoints do not require bearer tokens.

Protected endpoints require an access token issued by the User/OAuth Service.

Notes validates:

- Token signature
- Issuer
- Audience
- Expiration
- Required scopes / roles

The `authorId` is derived from JWT `sub`.

## 4.2 IDs / timestamps

- Business IDs: UUID strings
- Timestamps: ISO-8601 UTC

## 4.3 Pagination

List responses use:

```json
{
  "items": [],
  "page": 0,
  "size": 20,
  "totalElements": 0,
  "totalPages": 0
}
```

UI may request up to:

```text
size=100
```

Backend maximum:

```text
100
```

## 4.4 Public visibility rule

Anonymous users may see a note only when both are true:

```text
status = PUBLISHED
visibility = PUBLIC
```

A draft must never become public just because `visibility=PUBLIC`.

---

# 5. Category Model — Contract View

Category hierarchy is represented using `parentId`.

For the first live release, the public contract uses a single category resource rather than a separate SubCategory endpoint.

Expected category response fields from the full contract:

```text
id
name
slug
parentId
ancestorIds
level
active
sortOrder
version
createdAt
updatedAt
```

---

# 6. Endpoint Documentation — Public APIs

## 6.1 GET `/api/v1/public/categories`

### Purpose

Returns category nodes available to anonymous/public UI users.

### Authentication

None.

### Supported query patterns

Root categories:

```text
GET /api/v1/public/categories?rootOnly=true&page=0&size=100
```

Child categories:

```text
GET /api/v1/public/categories?parentId=<uuid>&page=0&size=100
```

### Response

Page of `CategoryResponse`.

### Important behavior

- Return only effectively active category nodes.
- UI initially uses the root-category list.
- Category hierarchy is navigated using `parentId`.

### UI use

Used to render category navigation/filtering.

---

## 6.2 GET `/api/v1/public/notes`

### Purpose

Returns anonymous/public note cards.

### Authentication

None.

### Request

Default example:

```text
GET /api/v1/public/notes?page=0&size=100&sort=publishedAt,desc
```

Optional filter:

```text
primaryCategoryId=<uuid>
```

### Response card fields

```text
id
slug
title
summary
primaryCategoryId
categoryName
tags
publishedAt
```

### Rules

- Exact category match.
- Return only published PUBLIC notes.
- Never include draft content.
- Never include Markdown body in card-list response.

### UI use

Used for public note listing screens.

---

## 6.3 GET `/api/v1/public/notes/{slug}`

### Purpose

Returns the public detail page for one note.

### Authentication

None.

### Path parameter

```text
slug
```

### Response fields

```text
id
slug
title
summary
contentMarkdown
primaryCategoryId
categoryName
tags
revisionNumber
publishedAt
```

### Visibility rules

Return `404` when the note is:

- absent
- DRAFT
- PRIVATE
- archived
- deleted
- otherwise not publicly accessible

### UI use

Used for the public note-detail page.

---

# 7. Endpoint Documentation — Protected APIs

## 7.1 POST `/api/v1/categories`

### Purpose

Creates a category.

### Authentication

Bearer token required.

### Required authorization

```text
Role: ADMIN
Scope: taxonomy.write
```

### Request body

```json
{
  "name": "Core Java",
  "slug": "core-java",
  "parentId": null,
  "sortOrder": 0
}
```

### Response

```text
201 Created
```

Body:

`CategoryResponse`

Headers:

```text
Location
ETag
```

### UI use

Used by the admin workspace to create categories.

---

## 7.2 GET `/api/v1/notes`

### Purpose

Returns the current owner's/authors' editable note list.

### Authentication

Bearer token required.

### Required authorization

```text
ADMIN/AUTHOR
notes.read
```

### Request

```text
GET /api/v1/notes?view=mine&page=0&size=100&sort=updatedAt,desc
```

### Response item fields

`NoteListItemResponse`:

```text
id
title
slug
summary
primaryCategoryId
tags
status
visibility
version
updatedAt
```

### Important rule

The list does not return the Markdown body.

### UI use

Owner/admin note-management list.

---

## 7.3 GET `/api/v1/notes/{id}`

### Purpose

Returns one editable note.

### Authentication

Bearer token required.

### Required authorization

```text
Owner or ADMIN
notes.read
```

### Response

Direct `NoteResponse`.

Includes editable:

```text
contentMarkdown
```

### ETag

Response includes:

```text
ETag: "note-<uuid>-v<N>"
```

### UI use

Loads the note editor.

---

## 7.4 POST `/api/v1/notes`

### Purpose

Creates a new note draft.

### Authentication

Bearer token required.

### Required authorization

```text
AUTHOR/ADMIN
notes.write
```

### Request body

```json
{
  "title": "ArrayList internals",
  "summary": "...",
  "contentMarkdown": "# ...",
  "primaryCategoryId": "uuid",
  "tags": ["java"],
  "visibility": "PUBLIC"
}
```

### Server-generated values

```text
id
slug
authorId = JWT sub
contentKind = NOTE
status = DRAFT
version = 0
createdAt
updatedAt
```

### Response

```text
201 Created
```

Body:

`NoteResponse`

Headers:

```text
Location
ETag
```

### Critical rule

`visibility=PUBLIC` does not expose a DRAFT.

### UI use

Creates a draft from the author/admin editor.

---

## 7.5 PATCH `/api/v1/notes/{id}`

### Purpose

Updates an existing draft.

### Authentication

Bearer token required.

### Required authorization

Owner + notes.write.

### Required header

```text
If-Match
```

### Editable fields

```text
title
summary
contentMarkdown
primaryCategoryId
tags
visibility
```

Omitted fields remain unchanged.

### Allowed state

Draft only.

### Response

```text
200 OK
```

Updated `NoteResponse` + new `ETag`.

### Concurrency behavior

- Missing `If-Match` -> `428`
- Stale `If-Match` -> `412`

### UI use

Saves draft edits.

---

## 7.6 POST `/api/v1/notes/{id}/submit`

### Purpose

Moves a draft into review.

### Authentication

Bearer token required.

### Required authorization

```text
Owner
notes.write
```

### Body

No JSON body.

### Required header

```text
If-Match
```

### State transition

```text
DRAFT -> IN_REVIEW
```

### Response

Updated `NoteResponse` + new `ETag`.

### UI use

Submit-for-review action.

---

## 7.7 POST `/api/v1/notes/{id}/publish`

### Purpose

Publishes a reviewed note.

### Authentication

Bearer token required.

### Required authorization

For the current owner-only phase:

```text
ADMIN
notes.review
```

### Body

No JSON body.

### Required header

```text
If-Match
```

### State transition

```text
IN_REVIEW -> PUBLISHED
```

### Required publication behavior

Publication must atomically:

1. Create an immutable revision/snapshot.
2. Update the published pointer/state.
3. Return the updated `NoteResponse`.
4. Return a new ETag.

### Owner-only self-publish note

The current contract allows an explicit audited ADMIN self-publish exception only after contract review. It must not be silently bypassed.

### Transaction requirement

MongoDB publication transaction requires replica-set support.

If publication transaction is not implemented, the system must not expose a misleading publish action/API behavior.

---

# 8. NoteResponse Contract

Current `NoteResponse` fields:

```text
id
title
slug
summary
contentMarkdown
primaryCategoryId
tags
contentKind
authorId
status
visibility
version
createdAt
updatedAt
```

The UI expects the updated response after every mutation and does not invent status locally.

---

# 9. Planned DTOs

## Category

```text
CreateCategoryRequest
CategoryResponse
```

## Notes — write

```text
CreateNoteRequest
UpdateNoteRequest
```

## Notes — protected read

```text
NoteResponse
NoteListItemResponse
```

## Notes — public read

```text
PublicNoteCardResponse
PublicNoteDetailResponse
```

## Common

```text
PageResponse<T>
ApiError
```

Exact Java field definitions and validation annotations will be finalized in the next DTO discussion.

---

# 10. Planned MongoDB Documents

The current implementation plan expects:

```text
CategoryDocument
NoteDocument
NoteRevisionDocument
```

The exact persisted fields, indexes, collection names, compound indexes, version strategy, and revision linkage will be finalized during the MongoDB/document-design discussion.

---

# 11. Shared Error Contract

Business error body:

```json
{
  "timestamp": "...",
  "status": 400,
  "code": "VALIDATION_FAILED",
  "message": "...",
  "path": "...",
  "traceId": "...",
  "fieldErrors": []
}
```

Expected status meanings:

| Status | Meaning |
|---|---|
| 400 | Validation failure |
| 401 | Missing/invalid access token |
| 403 | Insufficient scope/role |
| 404 | Unknown or inaccessible resource |
| 409 | Invalid state transition |
| 412 | Stale ETag |
| 428 | Missing If-Match |
| 503 | Service unavailable |

---

# 12. Minimum First-Live Flow

The minimum workflow is:

```text
Create root category
        ↓
Create DRAFT note
        ↓
Optional PATCH/edit
        ↓
Submit
        ↓
Publish
        ↓
Anonymous public list
        ↓
Anonymous public detail
```

---

# 13. First Live Release Acceptance Criteria

- Public category endpoint returns active categories.
- Public note list returns only published PUBLIC notes.
- Public note list never returns Markdown body.
- Public detail returns published snapshot.
- Draft is never publicly visible.
- PRIVATE note is never publicly visible.
- Archived/deleted note is never publicly visible.
- Category creation requires ADMIN + `taxonomy.write`.
- Protected note list is owner-scoped.
- Editable note detail includes `contentMarkdown`.
- Note creation produces DRAFT status.
- `authorId` is derived from JWT `sub`.
- PATCH supports optimistic concurrency.
- Missing `If-Match` produces 428.
- Stale ETag produces 412.
- Submit performs `DRAFT -> IN_REVIEW`.
- Publish performs `IN_REVIEW -> PUBLISHED`.
- Publish creates immutable revision/snapshot atomically.
- Admin self-publish exception is explicit/audited.
- Persistence survives restart.
- No endpoint is added, removed, or renamed for the first live release.

---

# 14. Implementation Order — Later Phase

1. Project baseline
2. MongoDB configuration
3. Enums
4. Category document
5. Note document
6. Revision document
7. DTOs
8. Repositories
9. Mappers
10. Category service/controller
11. Protected Note service/controller
12. Public Note service/controller
13. JWT resource-server security
14. ETag/If-Match handling
15. Submit transition
16. Publish transaction
17. Public snapshot reads
18. Unit tests
19. API/integration tests
20. Gateway integration
21. First live verification

---

## Contract Freeze Note

For the first live release, UI and backend must use the same endpoint paths and response contract documented here. Any later change must be reviewed and reflected in UI and backend together.
