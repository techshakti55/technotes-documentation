# TechNotes — User/OAuth Service specification

Version: 1.0 | Date: 2026-09-28 | Status: proposed implementation contract, ready for team review

**Owner: Shakti Singh. Developer 2 owns Notes Service and its MongoDB design.** This document defines a fresh Java service; it does not claim that its endpoints, repository or database already exist. No Jira tickets are created by this document.

Proposed repository name: `technotes-user-oauth-service` (creation pending).  
Suggested destination: `docs/user-oauth-service-spec.md`  
Companion: [Notes Service specification](../../notes/reference/spec-v1.md). Keep both original filenames together in the documentation repository for working relative links, or update the link when placing them in separate repositories.

## 1. Purpose and boundaries

Own user accounts, credentials, profile information, roles, OAuth client registrations and authorization-server state. Provide standards-based OAuth 2.0 authorization and OpenID Connect identity to TechNotes clients. Notes Service validates tokens and enforces ownership of its own content.

For a two-person team, User and OAuth are modules in **one deployable service** initially. This is a deliberate change from older architecture documents that listed Auth and User separately. Keep user/profile and authorization-server packages separate so they can be extracted later if necessary. No separate User microservice is required for the first milestone.

OAuth grants API access; OIDC supplies login identity. Use Spring Authorization Server's protocol implementation. A custom JSON `/api/v1/auth/login` that returns a home-made JWT is not part of this contract. The authorization server's form login authenticates a user during the redirect flow.

## 2. Milestones

| Stage | Deliverable | Exit condition |
|---|---|---|
| B0 — baseline | Application, PostgreSQL migration, persistent local signing key, health, tests | Both laptops run the same baseline |
| M1 — local secure MVP | User registration/profile, controlled role provisioning, OAuth code+PKCE, JWT issuance and validation | Notes integration succeeds for two different authors and a reader |
| M2 — account operations | Role/status administration, password/email workflows, public-release hardening | Recovery and privilege-change behavior tested |
| M3 — advanced integration | BFF/confidential clients, refresh-token policy, service identities, Kafka notifications | Separate threat model and contract reviewed |

M1 is for controlled local development. Public self-service account creation, email delivery/recovery and production deployment require the M2 operational gates. Do not represent `emailVerified=false` as verified or issue AUTHOR/ADMIN privileges from registration input.

## 3. Baseline and module structure

- Java 21, Maven Wrapper, Spring Boot **3.5.x target family**, Spring MVC, Spring Security, Spring Authorization Server **1.5.x family** compatible with the selected Boot BOM, OAuth2 Resource Server, Validation, Actuator, PostgreSQL, Flyway, Spring Data JPA/JDBC, JUnit and Testcontainers.
- Pin exact supported patches and verify the dependency tree in the first baseline PR. Use Boot dependency management instead of mixing arbitrary Security/Authorization Server versions. This specification does not claim any particular patch is already installed or currently maintained.
- Spring Cloud **2025.0.x target family** only when adding Eureka/Config dependencies. Keep OAuth issuer identity independent of a discovery service ID.
- Application port: **9000**; PostgreSQL laptop port: **5433**, container port: **5432**; database: `technotes_identity_db`. PostgreSQL is the proposed identity-store choice; Notes continues using MongoDB.
- Packages: `com.technotes.identity.user`, `role`, `oauth`, `security`, `config`, `common.error`, `audit`. Controllers use DTOs. Persistence entities never serialize password hashes or token state into API responses.
- Expected baseline files: Maven Wrapper, README, profiles, Flyway migrations, local Compose instructions, this specification, `.env.example` with placeholders. Generated secrets/private keys are gitignored and loaded from outside source control.

## 4. Origins, routing and token contract

| Component | Local URL / rule |
|---|---|
| Authorization issuer | `http://localhost:9000` — exact token issuer |
| OAuth endpoints and login UI | Browser talks directly to the issuer in M1 |
| Business API entry point | `http://localhost:8080` — API Gateway |
| User/Profile business API | Gateway forwards `/api/v1/users/**` to this service |
| Notes business API | Gateway forwards `/api/v1/notes/**`, `/api/v1/categories/**`, later `/api/v1/public/**` |
| Future React client | `http://localhost:5173` |
| Resource-server audience | `technotes-api` |

Do not prefix OAuth endpoints with `/api/v1` or rewrite issuer URLs through the Gateway in M1. If deployment later uses an auth subdomain, configure that canonical HTTPS issuer explicitly and test discovery, redirects and token validation together. In Docker, configure an internal JWKS URL separately when needed while continuing to validate the public `iss`; localhost inside a container is not the host machine.

### Access-token design

Use signed JWT access tokens with RS256 and a stable `kid`. Notes and User business APIs both require audience `technotes-api` in this initial first-party system. Proposed lifetime: 10 minutes; clock skew allowance: at most 60 seconds. Generate `sub` from the immutable user UUID, not the email or display name.

Required claims: `iss`, `sub`, `aud`, `iat`, `nbf`, `exp`, `jti`, space-separated `scope`, and string-array `roles`. Add audience and roles using a JWT token customizer; they are project requirements, not assumed framework defaults. Do not add credentials, internal hashes or personal profile data to access tokens. No user-role claims on future machine tokens.

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

Timestamps are illustrative. ID-token audience is the OAuth client ID; ID tokens must fail Notes API authorization. Each resource server checks JWT validity and then role, scope and resource ownership. User/OAuth does not make per-note authorization decisions.

### Roles and scopes

| Role | Proposed role-based scope ceiling |
|---|---|
| READER | openid, profile, email, profile.read, profile.write |
| AUTHOR | Reader scopes + notes.read, notes.write |
| REVIEWER | Reader scopes + notes.read, notes.review |
| ADMIN | Reader scopes + notes.read, notes.write, notes.review, taxonomy.write, users.manage |

Users may have multiple roles; take the union of allowed scopes. Token scopes are restricted by **registered-client allowance, requested/consented scopes and role ceiling**. Reject an authorization request containing a scope outside the resulting allowance with the protocol's `invalid_scope` behavior. A normal AUTHOR client request therefore must not request users.manage.

Role-based grant restriction and resource-server role conversion are custom implementation work. Test them explicitly. Registration always assigns READER; only controlled provisioning or the M2 admin API may grant AUTHOR, REVIEWER or ADMIN. A caller cannot self-promote through profile updates or claim headers.

## 5. OAuth client and sign-in sequence

M1 client: `technotes-web-local`, public client, authentication method `none`, grant `authorization_code`, PKCE S256 required, exact redirect URI **`http://localhost:5173/auth/callback`**, exact post-logout redirect **`http://localhost:5173/`**. Require user consent; persist it. Only register the first-party scope vocabulary above; no wildcard redirect URIs. Supply a minimal callback test page before the React application exists, or register a separate explicitly reviewed Postman callback client.

Spring's SPA guide documents that a public client does not receive refresh tokens. Therefore M1 does not promise browser refresh-token support. Keep browser access tokens in memory and start a new authorization flow on expiry/reload; the issuer session may avoid another password prompt. Consider a confidential BFF in M3 for server-side token storage and refresh, with its own cookie/CSRF contract. Never put a client secret in React.

Sequence for the M1 client:

1. Client generates state, nonce and a PKCE verifier/challenge using a maintained OIDC client library.
2. Browser navigates to `/oauth2/authorize` with code response type, exact callback and S256 challenge.
3. Issuer authenticates through its login page and obtains consent.
4. Callback validates state, then exchanges the returned short-lived, single-use code with the original verifier.
5. OIDC client validates the ID token including issuer, client audience and nonce. API requests use the access token.
6. Gateway forwards the token; Notes validates it independently and stores `authorId=sub`.

Authorization code lifetime target: 2 minutes. Invalid redirect URIs fail at the issuer without redirecting to the untrusted location. Password and implicit grants are excluded. Client credentials is deferred and will require a separate service identity contract.

## 6. Protocol endpoints — framework-owned

Configure these paths and OIDC explicitly; do not write business controllers that duplicate the protocol filters. Discovery/JWKS expose public metadata/keys only. They are not user-administration APIs.

| Stage | Method / endpoint | Caller and purpose | Main result |
|---|---|---|---|
| M1 | GET `/oauth2/authorize` | Browser; authorization code + S256 PKCE | Login/consent flow or registered callback redirect |
| M1 | POST `/oauth2/token` | Client; form-encoded code exchange | 200 token response |
| M1 | GET `/oauth2/jwks` | Resource servers; published public signing keys | 200 JWK Set |
| M1 | GET `/.well-known/oauth-authorization-server` | OAuth discovery | 200 metadata |
| M1 | GET `/.well-known/openid-configuration` | OIDC discovery | 200 metadata |
| M1 | GET `/userinfo` | Valid OIDC access token with openid | 200 allowed identity claims |
| M1 | GET `/login` | Browser login page | 200 HTML |
| M1 | POST `/login` | Browser form + session CSRF token | Redirect on success; login page on failure |
| M1 | POST `/logout` | Browser session + CSRF token | End local issuer session; configured redirect |
| M2 | GET `/connect/logout` | OIDC RP-initiated logout | Validated logout/confirmation flow |
| M3 | POST `/oauth2/revoke` | Authorized confidential client; form-encoded | 200 per OAuth revocation contract |
| M3 | POST `/oauth2/introspect` | Authorized confidential client | 200 active/inactive token metadata |

M1 application clients do not use introspection/revocation or refresh grants; framework paths may be registered but must reject unsupported/unauthenticated use. Dynamic client registration and device flow are not enabled for product clients. If the framework supports additional HTTP methods, the table records the method the TechNotes client will use, not a claim that other methods can never exist.

Example browser authorization URL, with placeholders that the client must generate and URL-encode:

```text
http://localhost:9000/oauth2/authorize?response_type=code&client_id=technotes-web-local&redirect_uri=http%3A%2F%2Flocalhost%3A5173%2Fauth%2Fcallback&scope=openid%20profile%20notes.read%20notes.write%20profile.read%20profile.write&state=<random-state>&nonce=<random-nonce>&code_challenge=<S256-challenge>&code_challenge_method=S256
```

An AUTHOR test user may request those scopes. A READER must request only its scope ceiling.

Token exchange uses `Content-Type: application/x-www-form-urlencoded`, not JSON:

```text
grant_type=authorization_code&client_id=technotes-web-local&code=<authorization-code>&redirect_uri=http%3A%2F%2Flocalhost%3A5173%2Fauth%2Fcallback&code_verifier=<original-verifier>
```

Illustrative successful token response:

```json
{
  "access_token": "<signed-access-token>",
  "token_type": "Bearer",
  "expires_in": 600,
  "scope": "openid profile notes.read notes.write profile.read profile.write",
  "id_token": "<signed-id-token>"
}
```

No `refresh_token` in this M1 public-client response. Token responses must not be cached. Invalid/reused code or verifier returns a protocol error such as 400 `invalid_grant`; client authentication errors follow framework OAuth behavior and may use 401. Authorization endpoint errors use the appropriate validated redirect only when safe. Do not wrap protocol errors inside the application's normal error envelope.

UserInfo's minimum field is `sub`. Add `name` only with profile scope and email/email_verified only with email scope and the agreed user mapping. Never return password hashes, reset tokens or private administration state.

## 7. Business endpoints — implemented by this team

User business API DTOs and errors are separate from OAuth responses. The service is a resource server for its protected business endpoints.

| Stage | Method / endpoint | Access | Success |
|---|---|---|---|
| M1 | POST `/api/v1/users/register` | Anonymous JSON, rate-limited; local controlled use | 201 User DTO |
| M1 | GET `/api/v1/users/me` | User bearer token + profile.read | 200 User DTO |
| M1 | PATCH `/api/v1/users/me` | User bearer token + profile.write + If-Match | 200 User DTO |
| M2 | GET `/api/v1/users` | ADMIN + users.manage | 200 paginated user summaries |
| M2 | GET `/api/v1/users/{id}` | ADMIN + users.manage | 200 User DTO |
| M2 | PUT `/api/v1/users/{id}/roles` | ADMIN + users.manage + If-Match | 200 User DTO |
| M2 | PATCH `/api/v1/users/{id}/status` | ADMIN + users.manage + If-Match | 200 User DTO |
| M2 | POST `/api/v1/users/me/password` | User bearer token + profile.write; verify current password | 204 |
| M2 | POST `/api/v1/users/password-reset-requests` | Anonymous; rate-limited | 202 generic acknowledgement |
| M2 | POST `/api/v1/users/password-resets` | Valid one-time reset proof | 204 |
| M2 | POST `/api/v1/users/email-verification-requests` | Anonymous; rate-limited | 202 generic acknowledgement |
| M2 | POST `/api/v1/users/email-verifications` | Valid one-time verification proof | 204 |
| B0 | GET `/actuator/health` | Local/internal only | 200 / 503 |

There is no public users directory or arbitrary user lookup for Notes in M1. Browser sessions alone cannot authorize business API endpoints; require bearer tokens. The public registration endpoint does not authenticate from a session cookie.

### 7.1 Register

```json
{
  "email": "author@example.test",
  "password": "<user-chosen-password>",
  "displayName": "Demo Author"
}
```

Validation: email trimmed and normalized to the documented lowercase account-identity policy, syntactically valid, maximum 254 characters; displayName trimmed, 1–100 characters; password 12–128 Unicode characters, not silently trimmed/truncated. Apply a maintained adaptive password encoder compatible with this length policy, proposed Argon2id with parameters benchmarked on the actual environment. Never log request bodies or include password in a response. Reject role, status, emailVerified, ID and unknown fields.

201 response:

```json
{
  "id": "89a8150a-d5c2-4bfd-8f53-d77200e3a771",
  "email": "author@example.test",
  "displayName": "Demo Author",
  "roles": ["READER"],
  "status": "ACTIVE",
  "emailVerified": false,
  "version": 0,
  "createdAt": "2026-09-28T12:00:00Z",
  "updatedAt": "2026-09-28T12:00:00Z"
}
```

Return `Location: /api/v1/users/me` and `ETag: "user-<uuid>-v0"`. Registration does not log in the user and does not return access tokens. Login uses the OAuth flow. Duplicate normalized email → 409 `EMAIL_ALREADY_REGISTERED` in this controlled M1 API. This explicitly reveals account existence; review a generic registration response before enabling public registration. Concurrent duplicate registrations must be caught by a database unique constraint.

### 7.2 Current profile

GET me derives the user ID exclusively from `sub`; return the User DTO above and its ETag. Unknown user → 404; disabled/locked local account → 403. PATCH me accepts only `displayName`; email changes are deferred until a dedicated verified-email-change design exists. The endpoint cannot change roles, status, password or emailVerified.

Existing-profile mutations use `If-Match: "user-<uuid>-v<version>"`. Missing header → 428; stale version → 412. Use JPA optimistic locking or equivalent atomic version updates and return the incremented version/ETag. No numeric user ID is accepted from a me request body.

### 7.3 M2 administration

- List query: `page=0&size=20`, max size 100, allowed sort `createdAt,asc|desc` with UUID tie-breaker; optional exact role/status filters. Email search is admin-only and must be bounded. Response: `items`, `page`, `size`, `totalElements`, `totalPages`; no hashes or tokens.
- PUT roles accepts `{"roles":["READER","AUTHOR"]}`; replace the complete role set, reject unknown/empty roles and audit old/new grants and acting admin. Prevent removing the last active ADMIN using transactional concurrency control, not a nonlocking count check.
- PATCH status accepts `{"status":"DISABLED","reason":"Account deactivated"}`. Allowed statuses: ACTIVE, LOCKED, DISABLED; reason required, 1–500 characters. Prevent disabling/locking the last active ADMIN. User deletion is deferred.
- Each administrative mutation invalidates applicable persisted authorizations and issuer sessions and blocks new issuance according to account state. Existing JWTs at offline resource servers may remain usable until expiry; the account response must not promise immediate cross-service invalidation.
- Protect self-administration paths and audit all privilege changes. Administrative authorization requires both role ADMIN and scope users.manage, even when Gateway already validated the token.
- For this service's own protected business APIs, check the current persisted account is ACTIVE. Administrative actions additionally require that the account still has ADMIN in the identity database, preventing a removed administrator from continuing identity administration with stale role claims. This local check does not imply an online account check exists in Notes Service.

### 7.4 M2 password and email workflows

Password change body: `{"currentPassword":"<current>","newPassword":"<new>"}`. Verify current password, enforce new-password policy, revoke persisted authorizations/sessions and audit the change. Rate-limit failures. Use 400 `CURRENT_PASSWORD_INVALID` without revealing hashes. The ten-minute offline JWT window still applies.

Reset request body: `{"email":"author@example.test"}`. Always return 202 `{"message":"If the account is eligible, instructions will be sent."}` for existing or absent accounts. Verification request uses the same shape and generic behavior. Store a hash of a cryptographically random proof, with purpose, user ID, expiry, consumedAt and attempt policy. Never put the raw proof into logs or database records. Delivery through a configured local mail sink can precede an actual email provider; successful delivery is required before claiming this workflow complete.

Reset completion body: `{"token":"<one-time-proof>","newPassword":"<new>"}`. Verification completion body: `{"token":"<one-time-proof>"}`. Atomically consume the matching, unexpired proof once. Invalid/expired/used proof → 400 with a generic code. Reset lifetime proposal: 15 minutes; email verification: 24 hours. Reset does not silently authenticate the user. Introduce request-size, attempt and delivery-rate limits before exposure.

### 7.5 Business API errors

```json
{
  "timestamp": "2026-09-28T12:00:00Z",
  "status": 400,
  "code": "VALIDATION_FAILED",
  "message": "Request validation failed",
  "path": "/api/v1/users/register",
  "traceId": "example-trace-id",
  "fieldErrors": [{"field": "displayName", "message": "must not be blank"}]
}
```

Shared mappings: 400 validation, 401 missing/invalid bearer, 403 forbidden, 404 unknown user, 409 duplicate email/invalid state, 412 version conflict, 413 request too large, 428 missing precondition, 429 rate limit, 503 database/dependency unavailable. Propose a 16 KiB JSON limit for user business requests; do not apply it blindly to framework endpoints with different payload requirements. Include Retry-After on throttling where meaningful. Protocol endpoints retain OAuth/OIDC errors.

## 8. PostgreSQL and persistence

| Table / store | Purpose and constraints |
|---|---|
| users | UUID PK, normalized_email UNIQUE NOT NULL, display_name, password_hash, status, email_verified, version, timestamps |
| roles | Fixed role codes READER, AUTHOR, REVIEWER, ADMIN |
| user_roles | Unique user_id + role_code, foreign keys to user/role |
| oauth2_registered_client | Persistent client registrations, exact redirects, grants and allowed scopes |
| oauth2_authorization | Persisted authorization/code/token state used by the selected framework |
| oauth2_authorization_consent | Persisted user/client consent |
| security_audit_events | Actor/target IDs, action, timestamp, outcome and trace ID; no secrets |
| account_action_tokens (M2) | Hashed reset/verification proofs with purpose/expiry/consumption state |
| JDBC session store (M2) | Issuer session persistence and invalidation across instances |

Use Spring Authorization Server JDBC repositories/services for its own tables; import the schema corresponding to the pinned version via reviewed Flyway migrations. Do not invent those internal table columns or let Hibernate recreate them. Business user tables can use JPA. Use `ddl-auto=validate` for integration/deployment profiles. Plan cleanup of expired authorization, proof and session records.

In-memory client/authorization repositories are test-only, not the team baseline. M1 may use an in-process issuer browser session on one local instance; restarting that instance logs the user out. Persisted authorization state and stable signing keys remain required. M2 clustered deployments require an explicit shared-session solution.

Signing keys are not ordinary user records. Load the private key from an external, gitignored local keystore; deployed keys come from a managed secret/key system. Keep public old keys until tokens signed by them expire plus skew. A process restart must not generate a new signing key automatically. Rotate kid and keys through a documented operation.

## 9. Security filter chains and release rules

1. Protocol chain: Spring Authorization Server endpoint matcher, explicit issuer, signing keys, registered clients, consent, token customization and OIDC configuration.
2. Business API chain: `/api/v1/users/**`, stateless JWT resource-server authentication, correct audience and method-level authorization; only the named registration/reset/verification request endpoints are anonymous in their enabled stage.
3. Browser chain: login/consent/logout pages and session authentication, CSRF protection and secure session-cookie settings. Do not globally disable CSRF to make a JSON test pass.

Separate browser and bearer API behavior carefully. Bearer-only stateless endpoints may have a narrowly scoped CSRF exemption; session-authenticated browser POSTs require CSRF. Define explicit chain order and test matchers for anonymous, bearer and cookie-only callers.

CORS: exact local origin `http://localhost:5173`, explicit methods/headers, and only the endpoints the browser calls. Configure Gateway CORS for business APIs and issuer CORS for token/UserInfo requests. CORS is not authorization. Production cookies are Secure, HttpOnly and use a SameSite policy tested with the deployment's login redirects. HTTP is local-loopback development only.

Disabling an account, changing roles/password, revoking stored authorization or logging out does **not** instantly invalidate an already issued offline-validated JWT. M1/M2 accept a bounded lifetime window; stricter immediate enforcement requires a separate online status/denylist strategy. Document this limitation in operational decisions rather than claiming logout instantly ends all API access.

Before public release: verified account policy, email delivery, password/rate-limit tests, backup/restore, persistent sessions as needed, signing-key rotation, audit retention, secret management, HTTPS, trusted proxy settings and exact callback/CORS configuration. Do not expose actuator internals or an unauthenticated OAuth-client administration API.

## 10. Local run and baseline completion

Proposed environment contract:

```dotenv
SERVER_PORT=9000
OAUTH_ISSUER_URI=http://localhost:9000
OAUTH_AUDIENCE=technotes-api
DATABASE_URL=jdbc:postgresql://localhost:5433/technotes_identity_db
DATABASE_USERNAME=<local-db-user>
DATABASE_PASSWORD=<local-db-password>
SIGNING_KEYSTORE_PATH=<absolute-gitignored-path>
SIGNING_KEYSTORE_PASSWORD=<local-secret>
WEB_REDIRECT_URI=http://localhost:5173/auth/callback
WEB_ORIGIN=http://localhost:5173
```

Bind these variables in baseline configuration; they are not automatically understood without that mapping. Add the chosen keystore type and alias to the implementation README. Never paste real values into GitHub or Jira.

IntelliJ: Project SDK and Maven runner JDK 21; Maven Wrapper; local profile. Start PostgreSQL, apply Flyway, then run:

```powershell
.\mvnw.cmd clean verify
.\mvnw.cmd spring-boot:run "-Dspring-boot.run.profiles=local"
```

For M1 local tests, create one ADMIN, two AUTHOR users and one READER through an idempotent, local-profile-only bootstrap command with environment-supplied secrets. It must not exist as a public HTTP endpoint or run in production. Record account IDs and role sets in a nonsecret test handoff, distribute temporary passwords privately, and require replacement. Developer 2 uses these identities to test owner isolation.

## 11. Testing and Definition of Done

- Fresh clone builds, Flyway succeeds on empty PostgreSQL, restart preserves users/client/authorization state and signing identity. Migration upgrade is tested, not just schema generation.
- Test duplicate normalized email concurrently; password hashes differ for equal passwords and verify correctly; DTO responses/logs never expose credentials.
- End-to-end code+PKCE works with browser login/consent; missing/wrong verifier, replayed/expired code, unregistered callback and unauthorized scope requests fail.
- Token contains the exact shared issuer/audience/roles/scope contract. JWKS contains public material only. ID tokens cannot call Notes or User business APIs.
- Test READER registration, AUTHOR provisioning, failed self-promotion, me isolation, wrong audience/issuer/signature, expiry and cookie-only API calls.
- Exercise real-token Gateway → Notes create/read and cross-author denial together with Developer 2. Validate the database contains sub as authorId.
- M2 tests cover last-admin concurrency, account disable/new issuance, session invalidation, one-time proof replay, generic recovery responses and the documented JWT invalidation window.
- Review filter-chain order, CSRF/CORS behavior, signing-key restart/rotation and error format boundaries. Attach build/API evidence and update README before PR approval.

## 12. Shakti's handoff and ticket sequencing

First review this contract together with the Notes specification. Then create the User/OAuth baseline and identity/security-model tickets for Shakti; create Notes baseline and Mongo/domain tickets for Developer 2. Actual Jira IDs will be assigned later.

Recommended implementation order: baseline and persisted users → client/key/protocol setup → claims/role-scope restrictions → current-user APIs → Notes integration → M2 administration/recovery. Feature branches use the actual new Jira key, such as `feature/<actual-jira-key>-identity-baseline`, with a reviewed PR into develop.

Handoff to Developer 2: issuer/JWKS URL, token claim contract, client/callback settings, nonsecret test account IDs/roles, error examples and known token-lifetime behavior. No Notes MongoDB credentials are needed by this service. Gateway routing must preserve paths and never manufacture identity headers.

## 13. Sources and decisions

Project sources: `TechNotes_Project_HQ_Master_v1.docx` and `TechNotes_Notes_Service_Company_Standard_v1.docx`, read on 2026-09-28. Latest owner assignment overrides older discussion: Shakti → User/OAuth; Developer 2 → Notes/MongoDB.

Primary technical references checked on 2026-09-28:

1. [Spring Authorization Server: SPA with PKCE](https://docs.spring.io/spring-authorization-server/reference/guides/how-to-pkce.html) — public clients, redirect flow and refresh-token limitation.
2. [Spring Authorization Server: configuration model](https://docs.spring.io/spring-authorization-server/reference/configuration-model.html) — protocol endpoints, issuer settings and OIDC configuration.
3. [Spring Authorization Server: core model/components](https://docs.spring.io/spring-authorization-server/reference/core-model-components.html) — clients, authorizations, consent and persistence components.
4. [Spring Security: JWT resource server](https://docs.spring.io/spring-security/reference/servlet/oauth2/resource-server/jwt.html) — JWT validation and authority conversion; use reference/API versions aligned with the chosen Boot release when coding.

Ports, database choice, limits, role/scope policy, milestones, account APIs and security lifetimes are TechNotes design proposals. Exact dependency patches, production origin, deployment secrets, email provider and public-registration behavior must be recorded during implementation. Both developers should review the contract before tickets lock in these details.