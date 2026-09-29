# First live release - public Notes

**Status:** fixed UI/backend contract; implementation and deployment require verification. **Date:** 29 Sep 2026.

## Product result

Shakti signs in with a privately provisioned owner account, creates a category and Markdown note, saves, submits and publishes. Anonymous visitors read only the immutable published snapshot when status is PUBLISHED and visibility PUBLIC. Drafts, PRIVATE, archived and deleted notes never appear publicly.

| Owner | Contract | Persistence |
| --- | --- | --- |
| Shakti - User/OAuth | [OAuth](oauth.md) | PostgreSQL user/OAuth state; stable signing key |
| Developer 2 - Notes | [Notes](notes.md) | MongoDB categories, notes and revisions |
| UI | [React mapping](ui-integration.md) | Static frontend |
| Gateway | Preserve routes, bearer token, ETag/If-Match | No business data |

## Integration order

1. Verify issuer, Gateway and Notes local URLs and health.
2. Provision owner and public PKCE client; verify code exchange and users/me.
3. Create root category, draft, owner read and edit.
4. Submit and publish with explicit audited ADMIN self-publish exception and atomic Mongo revision/pointer update.
5. Verify anonymous list/detail and privacy failures; then disable UI demo mode.
6. Before public deployment, verify HTTPS, exact issuer/callback/CORS, durable stores, backup and rollback.

## Fixed API surface

- OAuth framework: GET /oauth2/authorize, POST /oauth2/token, GET /oauth2/jwks, browser GET/POST /login; business: GET /api/v1/users/me.
- Notes public: GET /api/v1/public/categories, GET /api/v1/public/notes, GET /api/v1/public/notes/{slug}.
- Notes protected: POST /api/v1/categories, GET /api/v1/notes, GET /api/v1/notes/{id}, POST /api/v1/notes, PATCH /api/v1/notes/{id}, POST /api/v1/notes/{id}/submit, POST /api/v1/notes/{id}/publish.

Do not add, remove or rename custom business endpoints for this release. The framework login page is part of OAuth, not a new custom API. Detailed DTOs and errors are in the service contracts.

## Later

Public signup, free-account gating, Premium, payment, community blogs, search, uploads, Kafka and notifications. [Product roadmap](../product/product-blueprint.md) describes future direction, not today's checklist.
