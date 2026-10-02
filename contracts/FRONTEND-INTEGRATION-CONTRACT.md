# TechNotes First-Live Frontend Integration Contract

> Shared integration contract for the existing TechNotes React UI, API Gateway, OAuth/User Service, and Notes Service.
>
> Goal: connect the current UI baseline for First Live with the minimum required backend integration. Do not redesign or enhance the UI as part of this release.
>
> This file is an integration map. Service-specific API/domain contracts remain canonical in their own first-live documents. If this file conflicts with a service's frozen contract, fix the documentation before coding; do not invent behavior in a consuming service.

## 1. First-Live Principle

For the current release:

- Keep the existing React UI structure and screens unless a small integration-only change is required.
- Do not add Blog, Subscription, Topic, social-login, signup, or other archived/future features.
- Do not rename or invent Notes endpoints.
- Do not hard-code secrets, access tokens, authorization codes, passwords, or private signing keys.
- Backend authorization is authoritative. UI role/scope checks are only for presentation/UX.
- Runtime URLs must remain configuration driven where the current UI/backend structure supports it.

Future UI redesign/refactoring is allowed after First Live without changing backend contracts merely for presentation changes.

## 2. Local Integration Baseline

| Component | Local address / identity |
|---|---|
| React UI | `http://localhost:5173` |
| API Gateway | `http://localhost:8080` |
| OAuth/User Service issuer | `http://localhost:9000` |
| OAuth client | `technotes-web` |
| OAuth callback | `http://localhost:5173/auth/callback` |
| API audience | `technotes-api` |
| Eureka | `http://localhost:8761/eureka/` |
| OAuth JWKS | `http://localhost:9000/oauth2/jwks` |

AWS/public URLs are not frozen yet. Do not hard-code localhost URLs into Java classes. Frontend runtime/build configuration should hold environment-specific browser URLs using the convention already present in the UI repository. Do not create duplicate environment-variable names before inspecting the existing UI.

## 3. Browser Authentication Flow

The React application uses OAuth 2.0 Authorization Code with PKCE S256.

Expected browser flow:

```text
React UI
  |
  | generate state
  | generate nonce
  | generate PKCE code_verifier
  | derive S256 code_challenge
  v
GET http://localhost:9000/oauth2/authorize
  |
  | client_id=technotes-web
  | redirect_uri=http://localhost:5173/auth/callback
  | response_type=code
  | requested scope
  | state
  | nonce
  | code_challenge
  | code_challenge_method=S256
  v
OAuth issuer /login
  |
  | user authenticates on issuer-owned login page
  v
React /auth/callback?code=...&state=...
  |
  | verify returned state
  | recover PKCE verifier for this transaction
  v
POST http://localhost:9000/oauth2/token
  |
  | authorization_code
  | code
  | client_id=technotes-web
  | exact redirect_uri
  | code_verifier
  v
Access token
```

React must not collect the OAuth account password in its own application form for this First-Live flow. `/login` is issuer-owned.

React must not send an ID token as the bearer credential to Notes or other TechNotes APIs. Application APIs require the access token whose audience contains `technotes-api`.

## 4. Direct OAuth Traffic vs Gateway Traffic

### Direct to OAuth/User Service for First Live

These protocol/browser endpoints remain direct to the issuer at `http://localhost:9000`:

- `GET /oauth2/authorize`
- `GET /login`
- `POST /login` (framework form/session/CSRF flow)
- `POST /oauth2/token`
- `GET /oauth2/jwks`

Do not move these endpoints behind Gateway merely because Gateway/Eureka exist. The issuer remains `http://localhost:9000` for Local First Live.

### Through API Gateway

React application API calls use the Gateway at `http://localhost:8080`:

```text
/api/v1/users/**        -> OAuth/User Service
Notes frozen API paths -> Notes Service
```

Protected application requests carry:

```http
Authorization: Bearer <access-token>
```

Gateway must preserve this header when forwarding the request. Downstream services still validate/authorize the token themselves.

## 5. JWT Contract Consumed by UI, Gateway, and Notes

Frozen token contract:

```json
{
  "iss": "http://localhost:9000",
  "sub": "<persisted-user-uuid>",
  "aud": ["technotes-api"],
  "scope": "openid profile notes.read notes.write taxonomy.write profile.read",
  "roles": ["ADMIN"],
  "iat": 0,
  "nbf": 0,
  "exp": 0
}
```

The example shows claim shape only. Actual scopes depend on what was requested and granted.

Rules:

- `sub` is the persisted user's immutable UUID serialized as a string.
- `roles` is a JSON array.
- `scope` is a space-separated string.
- Role and scope are independent.
- ADMIN does not automatically imply every scope.
- Notes Service must independently validate signature, issuer, lifetime and audience.
- UI may use user/authorization information to show or hide controls, but this never replaces server authorization.

Registered First-Live scopes:

`openid profile notes.read notes.write notes.review taxonomy.write profile.read`

## 6. Current User Integration

React calls the application API through Gateway:

```http
GET http://localhost:8080/api/v1/users/me
Authorization: Bearer <access-token>
```

Required scope: `profile.read`.

Successful response fields:

- `id`
- `displayName`
- `email`
- `roles`
- `status`

Frozen error behavior:

- missing/invalid bearer token -> `401`
- bearer token without `profile.read` -> `403`
- token `sub` has no persisted account -> `404 USER_NOT_FOUND`
- persisted account is deactivated -> `403 USER_DEACTIVATED`

UI should treat the backend response as authoritative; it must not synthesize a user identity from editable client data.

## 7. Notes API Paths Used by React/Gateway

These are the fixed First-Live Notes endpoints. Gateway must route these exact paths to Notes Service; UI must not invent alternate paths.

### Anonymous/Public

```text
GET /api/v1/public/categories
GET /api/v1/public/notes
GET /api/v1/public/notes/{slug}
```

Public behavior:

- public categories expose active categories according to the Notes contract.
- public note list/detail expose only content that is both `PUBLISHED` and `PUBLIC`.
- draft/private/archived/deleted content must not become public because of UI filtering; the backend enforces this.
- public list must not expose editable Markdown body.
- public detail returns the immutable published snapshot, not the mutable draft document.

### Protected

```text
POST /api/v1/categories
GET /api/v1/notes
GET /api/v1/notes/{id}
POST /api/v1/notes
PATCH /api/v1/notes/{id}
POST /api/v1/notes/{id}/submit
POST /api/v1/notes/{id}/publish
```

Important integration rules:

- React must not supply/trust an `authorId` as owner identity. Notes Service derives `authorId` from JWT `sub`.
- protected note reads are owner-scoped according to the Notes contract.
- creating a note creates a `DRAFT` according to the Notes contract.
- submit is the frozen `DRAFT -> IN_REVIEW` transition.
- publish follows the frozen Notes authorization/state policy and creates the immutable published snapshot atomically.
- ADMIN self-publish exception, when applicable under the Notes contract, is audited server-side.
- Category creation requires the frozen Notes authorization policy; the shared security contract establishes that ADMIN role and `taxonomy.write` are independent and both must be evaluated as required by that policy.

Request/response DTO field definitions, filters, pagination and state rules remain canonical in `docs/first-live/notes.md`; do not duplicate or reinterpret them here.

## 8. ETag / If-Match UI Contract

Editable Notes use optimistic concurrency.

Expected UI flow:

```text
GET editable note
   |
   | receive response + ETag
   v
UI edits note
   |
   | PATCH same note
   | If-Match: <ETag received for editable version>
   v
Notes Service
```

Frozen outcomes:

- missing required `If-Match` -> `428 Precondition Required`
- stale ETag/version -> `412 Precondition Failed`
- successful mutation returns/uses the current representation/version according to the Notes API contract; React must replace its stored ETag when a newer one is returned.

React must not silently retry a stale update as if it were current. A `412` requires a refresh/reconciliation UX; First Live may keep that UX minimal.

## 9. Gateway Requirements for Frontend Integration

Gateway is the common entry point for application APIs, not the OAuth issuer.

Gateway First-Live responsibilities:

- route `/api/v1/users/**` to OAuth/User Service.
- route the frozen Notes paths to Notes Service.
- preserve `Authorization: Bearer ...` on protected requests.
- use the existing Eureka/service-discovery setup when the target services are registered and verified.
- keep service locations environment/config driven.
- support the React origin according to the project's chosen CORS ownership/configuration.
- do not create duplicate business authorization that replaces service-level authorization.

Expected local application flow:

```text
React :5173
   |
   +---- OAuth protocol/login ----------> OAuth/User :9000
   |
   +---- application API ---------------> Gateway :8080
                                             |
                                             +--> /api/v1/users/** -> OAuth/User
                                             |
                                             +--> Notes paths ------> Notes Service
```

## 10. Eureka Boundary

Eureka provides service registration/discovery. It does not authenticate users and does not validate application authorization.

For integration baseline, verify that the existing components intended to use discovery are registered/healthy before switching Gateway routes to service-name routing.

Conceptually:

```text
Eureka -> where is the service?
Gateway -> where should this request be routed?
OAuth -> who authenticated / who issued this token?
Notes -> is this token valid and is this operation authorized?
```

Do not change OAuth issuer semantics simply because OAuth/User Service is also registered with Eureka.

## 11. CORS and Browser Boundary

The browser origins differ locally (`5173`, `8080`, `9000`), so CORS must be handled deliberately.

First-Live intent:

- application API traffic originates from React and targets Gateway.
- OAuth protocol traffic targets the OAuth issuer directly where required by the frozen flow.
- allow only the required local UI origin during local development rather than using unrestricted wildcard credentials policies.
- exact CORS ownership/configuration must follow the existing Gateway/OAuth implementation discovered during integration baseline; do not create competing CORS configurations in multiple layers without need.

## 12. Frontend Configuration Rule

Before editing the React project, inspect the current UI ZIP/repository and reuse its existing configuration convention.

Required logical values are:

- API base URL = local Gateway (`http://localhost:8080`)
- OAuth issuer = `http://localhost:9000`
- OAuth client ID = `technotes-web`
- OAuth redirect URI = `http://localhost:5173/auth/callback`
- requested scopes = only those needed for the current user/feature flow

If the current Vite UI already has environment-variable names for these values, reuse them. If not, freeze names in the UI change before implementation. Do not maintain two competing names for the same setting.

No secret belongs in a `VITE_*` variable: browser-delivered variables are public to the client.

## 13. Minimum First-Live UI Work

The current UI is the baseline. For this release, frontend work should be limited to what is required to make the existing screens functional:

1. wire Authorization Code + PKCE S256 login.
2. implement/verify `/auth/callback` processing and state validation.
3. obtain/use the access token for application APIs.
4. call `/api/v1/users/me` through Gateway when current-user data is needed.
5. point Notes API calls to Gateway using the frozen Notes endpoints.
6. attach bearer access token only to protected application calls.
7. capture/send ETag/If-Match for editable-note concurrency.
8. handle required first-live HTTP states (`401`, `403`, `404`, `409`, `412`, `428` and validation errors) with minimal existing-UI-compatible feedback.

Do not redesign screens or add new product features merely to complete integration.

## 14. Future UI Enhancements

After First Live, the React UI may be redesigned/refactored independently, including component structure, visual design, responsive behavior, editor UX, navigation, loading states and other presentation improvements.

A UI-only enhancement does not require a backend contract change. If a future feature truly needs a new/changed API, update the relevant canonical contract first (or in the same coordinated change) and then update Gateway/service/UI consumers.

## 15. Frozen vs Pending

### Frozen for First Live

- React local origin `http://localhost:5173`.
- Gateway local base `http://localhost:8080`.
- OAuth issuer `http://localhost:9000`.
- client `technotes-web`.
- callback `http://localhost:5173/auth/callback`.
- Authorization Code + PKCE S256.
- audience `technotes-api`.
- JWT `sub`, `roles`, and `scope` shapes defined by the shared security contract.
- direct OAuth protocol endpoints vs Gateway application API split.
- `/api/v1/users/me` behavior.
- fixed Notes endpoint paths listed above.
- backend-derived note owner from JWT `sub`.
- ETag/If-Match concurrency semantics (`428`/`412`).
- no ID token as Notes/API bearer token.
- no UI redesign required for First Live.

### Pending / must not be invented here

- final AWS/public URLs and deployment topology.
- access-token lifetime policy.
- authorization-code lifetime policy.
- clock-skew policy.
- consent policy.
- unresolved Notes authorization decisions explicitly marked pending in canonical Notes/security documents (including any final ADMIN/AUTHOR relationship policy).
- exact frontend environment-variable names if the current UI has not already frozen them.
- any future UI feature/API expansion.

## 16. Canonical Sources and Change Rule

Use these documents together:

- `contracts/SECURITY-INTEGRATION-CONTRACT.md` -> OAuth/JWT/Gateway security boundary and shared claims.
- `docs/first-live/notes.md` -> Notes endpoint/domain/request/response/state contract.
- OAuth/User First-Live implementation/contract documents -> issuer/login/token/user behavior.
- this file -> React/Gateway/backend integration map.

If OAuth claims, scopes, issuer strategy, API audience, Notes endpoint paths, callback, Gateway-visible routes, or frontend/backend integration assumptions change, update the appropriate canonical contract first (or in the same coordinated PR) and then update consuming services.

Never put passwords, private signing keys, authorization codes, live access tokens, refresh tokens, or other secrets in this repository.