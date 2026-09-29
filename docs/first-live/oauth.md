# TechNotes First Live Release — User/OAuth Service Documentation

**Date:** 29 Sep 2026  
**Owner:** Shakti  
**Service:** User/OAuth Service  
**Database:** PostgreSQL  
**Local Issuer:** `http://localhost:9000`  
**Gateway:** `http://localhost:8080`  
**React UI:** `http://localhost:5173`  
**Release Scope:** First live release only. Endpoint contract must remain unchanged.

---

## 1. Service Purpose

The User/OAuth Service is responsible for:

- User authentication using OAuth 2.0 Authorization Code flow with PKCE S256.
- Issuing access tokens for the TechNotes UI.
- Exposing public signing keys through JWKS.
- Returning the authenticated user's profile.
- Providing roles/scopes required by the Notes Service.
- Persisting OAuth-related state in PostgreSQL.
- Using a stable signing key so application restart does not invalidate all unexpired tokens.

Public signup is not part of the first live release. One owner/admin account is provisioned privately.

---

## 2. First Live Release Scope

### Included endpoints

| Method | Path | Purpose |
|---|---|---|
| GET | `/oauth2/authorize` | Start browser OAuth authorization flow using Authorization Code + PKCE |
| POST | `/oauth2/token` | Exchange authorization code + verifier for access token |
| GET | `/oauth2/jwks` | Expose public signing keys for JWT validation |
| GET | `/api/v1/users/me` | Return authenticated user profile |

The authorization server also serves its browser login form at GET/POST `/login` as part of the framework flow. These are not additional custom business APIs.

### Out of scope for this release

- Public signup
- Password-reset API
- User management CRUD
- Multiple-account onboarding flows
- Additional profile APIs
- Refresh-token customization beyond framework behavior
- Any endpoint rename/add/remove

---

## 3. Proposed File Structure

> This is the implementation structure to follow when development starts. It does not change the API contract.

```text
technotes-user-oauth-service/
├── pom.xml
├── Dockerfile
├── src/
│   ├── main/
│   │   ├── java/com/technotes/auth/
│   │   │   ├── TechNotesUserOAuthApplication.java
│   │   │   │
│   │   │   ├── config/
│   │   │   │   ├── AuthorizationServerConfig.java
│   │   │   │   ├── SecurityConfig.java
│   │   │   │   ├── CorsConfig.java
│   │   │   │   └── JwtConfig.java
│   │   │   │
│   │   │   ├── controller/
│   │   │   │   └── UserProfileController.java
│   │   │   │
│   │   │   ├── dto/
│   │   │   │   └── UserProfileResponse.java
│   │   │   │
│   │   │   ├── entity/
│   │   │   │   └── UserAccount.java
│   │   │   │
│   │   │   ├── enums/
│   │   │   │   ├── UserRole.java
│   │   │   │   └── UserStatus.java
│   │   │   │
│   │   │   ├── repository/
│   │   │   │   └── UserAccountRepository.java
│   │   │   │
│   │   │   ├── service/
│   │   │   │   ├── UserProfileService.java
│   │   │   │   └── TokenClaimsService.java
│   │   │   │
│   │   │   ├── security/
│   │   │   │   ├── JwtClaimsCustomizer.java
│   │   │   │   └── OAuthUserDetailsService.java
│   │   │   │
│   │   │   └── exception/
│   │   │       ├── ApiError.java
│   │   │       └── GlobalExceptionHandler.java
│   │   │
│   │   └── resources/
│   │       ├── application.yml
│   │       ├── application-local.yml
│   │       └── db/migration/
│   │
│   └── test/
│       └── java/com/technotes/auth/
│           ├── AuthorizationFlowTest.java
│           ├── TokenEndpointTest.java
│           └── UserProfileControllerTest.java
```

---

## 4. Shared Security Contract

### Required OAuth flow

The browser must use:

- Authorization Code flow
- PKCE
- `code_challenge_method=S256`
- `state`
- `nonce`
- No client secret in React

### Client

```text
client_id = technotes-web
```

### Redirect URI

```text
http://localhost:5173/auth/callback
```

### Required scopes

```text
openid
profile
notes.read
notes.write
notes.review
taxonomy.write
profile.read
```

### Required access-token claims

```text
iss
sub
aud
scope
roles
iat
nbf
exp
```

Expected important values:

```text
sub   = immutable user UUID
aud   = ["technotes-api"]
roles = ["ADMIN"]  (AUTHOR may also be included if Notes policy requires it)
```

---

# 5. Endpoint Documentation

## 5.1 GET `/oauth2/authorize`

### Purpose

Starts the browser-based authorization flow.

This endpoint is OAuth framework-owned. It is not a custom JSON business endpoint.

### Called by

React UI / browser.

### Request

Example logical request:

```text
GET http://localhost:9000/oauth2/authorize
```

Query parameters:

| Parameter | Required | Expected value / rule |
|---|---|---|
| `response_type` | Yes | `code` |
| `client_id` | Yes | `technotes-web` |
| `redirect_uri` | Yes | Exact configured callback |
| `scope` | Yes | Required application scopes |
| `state` | Yes | Browser-generated |
| `nonce` | Yes | Browser-generated |
| `code_challenge` | Yes | PKCE challenge |
| `code_challenge_method` | Yes | `S256` |

### Success behavior

After successful authentication/consent, the browser is redirected to the UI callback with:

```text
code
state
```

### Validation / security rules

- Exact registered redirect URI must be used.
- PKCE S256 must be used.
- Original `state` must be preserved.
- Authorization code must not be reusable.
- No private client secret is stored in React.

### UI use

The React UI uses this endpoint to start login.

---

## 5.2 POST `/oauth2/token`

### Purpose

Exchanges the authorization code and PKCE verifier for an access token.

### Content-Type

```text
application/x-www-form-urlencoded
```

### Request fields

| Field | Required |
|---|---|
| `grant_type=authorization_code` | Yes |
| `client_id=technotes-web` | Yes |
| `code` | Yes |
| `redirect_uri` | Yes |
| `code_verifier` | Yes |

### Example response shape

```json
{
  "access_token": "...",
  "token_type": "Bearer",
  "expires_in": 600
}
```

Additional standard OAuth/OpenID fields may be returned by the framework.

### Security rules

- Exact original redirect URI must be supplied.
- Wrong verifier must fail.
- Replayed authorization code must fail.
- React must not send a client secret.
- Token endpoint CORS must allow only the configured UI origin.

### UI use

The React UI exchanges the returned authorization code for the access token used with protected Gateway APIs.

---

## 5.3 GET `/oauth2/jwks`

### Purpose

Exposes the public JWK Set used by resource servers to validate token signatures.

### Authentication

Public endpoint.

### Response

JWK Set containing public signing key information.

### Consumer

Notes Service.

### Important rules

Notes Service must validate:

- Signature
- Exact issuer
- Audience
- Expiration
- Correct access-token type/use

Wrong issuer, wrong audience, invalid signature, expired token, or inappropriate token must be rejected.

---

## 5.4 GET `/api/v1/users/me`

### Purpose

Returns the currently authenticated owner's profile.

### Route

Business API is called through Gateway:

```text
GET /api/v1/users/me
```

### Authentication

Bearer access token required.

### Required scope

```text
profile.read
```

### Success response

Direct JSON object:

```json
{
  "id": "uuid",
  "displayName": "Shakti Singh",
  "email": "...",
  "roles": ["ADMIN"],
  "status": "ACTIVE"
}
```

### Response DTO

`UserProfileResponse`

Suggested fields based on the current contract:

```text
id
displayName
email
roles
status
```

### Error behavior

| Status | Meaning |
|---|---|
| 401 | Missing/invalid access token |
| 403 | Required scope/role missing |
| 404 | User profile not available/inaccessible |

### UI use

Used by the owner/admin workspace to identify the logged-in user and display authorization context.

---

# 6. PostgreSQL Responsibility

PostgreSQL is used for persistent OAuth/user state required by this service.

The first live release requires persistence across restart and a stable signing key strategy.

Implementation details such as the exact schema/table design will be finalized during implementation discussion.

---

# 7. Shared Response / Error Rules

Business JSON resources use direct objects.

Common business error format:

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

IDs are UUID strings.  
Timestamps are ISO-8601 UTC.

---

# 8. First Live Release Acceptance Criteria

- Authorization Code + PKCE S256 works.
- Correct callback URI is enforced.
- Authorization code replay fails.
- Wrong code verifier fails.
- Token endpoint CORS is configured for the UI origin.
- UI contains no private client secret.
- Access token contains required issuer/audience/scopes/roles.
- Stable signing key is used.
- OAuth state survives service restart.
- JWKS endpoint exposes public key material.
- Notes Service can validate issued access tokens.
- `/api/v1/users/me` returns the owner profile for a valid token.
- `/api/v1/users/me` returns 401 without a valid access token.
- No endpoint is added, removed, or renamed for the first live release.

---

# 9. Implementation Order — Later Phase

1. Project baseline
2. PostgreSQL configuration
3. User/account persistence
4. Authorization Server configuration
5. Registered public client configuration
6. PKCE/CORS configuration
7. JWT claims customization
8. Stable key configuration
9. `/api/v1/users/me`
10. Integration tests
11. Gateway integration
12. Notes token-validation integration
13. Live verification

---

## Contract Freeze Note

For the first live release, the endpoint contract is frozen. Backend and UI must use the same paths, request shapes, scopes, and response shapes documented above.
