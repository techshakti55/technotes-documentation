# TechNotes Security Integration Contract

> Canonical contract for Notes Service and API Gateway integration with the TechNotes OAuth/User Service.
>
> First Live rule: consumers should read values from this contract, but runtime configuration must remain environment/config driven. Do not copy secrets into this repository.

## 1. OAuth / JWT Contract

| Item | Contract |
|---|---|
| Local OAuth issuer | `http://localhost:9000` |
| API audience | `technotes-api` |
| Subject (`sub`) | Persisted user's immutable UUID, serialized as a string |
| `roles` claim | JSON array of role names, e.g. `["ADMIN"]` |
| `scope` claim | Space-separated string of granted scopes |
| Local JWKS endpoint | `http://localhost:9000/oauth2/jwks` |
| OAuth client ID | `technotes-web` |
| Local UI origin | `http://localhost:5173` |
| Local Gateway | `http://localhost:8080` |
| Local callback | `http://localhost:5173/auth/callback` |

Registered First Live scopes:

`openid profile notes.read notes.write notes.review taxonomy.write profile.read`

Important authorization rule: roles and scopes are independent. An ADMIN token contains `taxonomy.write` only when that scope was requested and granted. ADMIN role must not be treated as automatically adding scopes.

Access tokens for TechNotes APIs must contain audience `technotes-api`. OIDC ID tokens must not be accepted as bearer access tokens by Notes Service or other TechNotes APIs.

## 2. Notes Service Requirements

Notes Service is a protected Resource Server.

It must validate bearer access tokens independently rather than relying only on API Gateway. Validation must include:

- JWT signature using the OAuth server's public signing key/JWKS.
- issuer matching the configured TechNotes issuer.
- token lifetime (`exp`, and applicable `nbf` validation).
- audience containing `technotes-api`.
- endpoint authorization using the required scopes and/or roles defined by the Notes API authorization policy.

Claims available to Notes Service:

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

The claims above show shape only. Exact scopes in a token depend on what was requested and granted.

Do not use an ID token as the bearer token for Notes APIs.

## 3. OAuth/User Service API Needed by Gateway

Current-user endpoint:

`GET /api/v1/users/me`

Requires bearer access token with `profile.read`.

Successful response fields:

- `id`
- `displayName`
- `email`
- `roles`
- `status`

Account-state behavior:

- missing/invalid bearer token -> `401`
- bearer token without `profile.read` -> `403`
- JWT subject with no persisted account -> `404 USER_NOT_FOUND`
- persisted but deactivated account -> `403 USER_DEACTIVATED`

## 4. API Gateway Requirements

Local Gateway port: `8080`.

Gateway is the common entry point for application APIs. It should route application API paths to the owning service and preserve the incoming `Authorization: Bearer ...` header when forwarding protected requests.

Required First Live routing domains:

- `/api/v1/users/**` -> OAuth/User Service
- Notes API paths -> Notes Service (use the Notes Service's frozen endpoint paths; do not invent new paths in Gateway)

The Gateway repository already includes Spring Cloud Gateway, Eureka Client and Actuator. Prefer Eureka/service-name based routing when the target service is registered and verified in Eureka. Keep service addresses configuration driven for Local/AWS environments.

### OAuth endpoints that remain direct for First Live

The following issuer/browser/token endpoints remain on the OAuth service for the current First Live contract:

- `/oauth2/authorize`
- `/login`
- `/oauth2/token`
- `/oauth2/jwks`

Do not change the OAuth issuer from `http://localhost:9000` merely to place these endpoints behind Gateway. A future public-domain/AWS issuer change is a separate deployment decision.

## 5. Gateway vs Service Security Boundary

Gateway routing does not replace service-level JWT validation.

Expected request flow:

```text
React UI :5173
      |
      v
API Gateway :8080
      |
      +---- /api/v1/users/** ----> OAuth/User Service :9000
      |
      +---- Notes API paths -----> Notes Service
```

For protected Notes requests:

```text
UI
  -> Gateway
       Authorization: Bearer <access-token>
  -> Notes Service
       validate signature
       validate issuer
       validate audience = technotes-api
       validate expiry/not-before
       enforce endpoint scope/role policy
```

## 6. Local vs AWS Configuration

### LOCAL

- OAuth issuer: `http://localhost:9000`
- Gateway: `http://localhost:8080`
- UI: `http://localhost:5173`
- Callback: `http://localhost:5173/auth/callback`
- Eureka: `http://localhost:8761/eureka/`

### AWS

AWS hostnames/service addresses are intentionally not frozen yet. Production values must be supplied through environment/deployment configuration. Do not hard-code localhost URLs into Java classes.

The OAuth signing private key must never be stored in Git. The OAuth service's persistent signing-key design remains the source of JWT signatures; consumers use only public key/JWKS material.

## 7. Frozen vs Pending Decisions

Frozen for First Live:

- OAuth client: `technotes-web`
- API audience: `technotes-api`
- subject: persisted user UUID
- `roles`: JSON array
- `scope`: space-separated string
- PKCE S256 for browser authorization-code flow
- Notes/API services reject ID tokens as API bearer tokens
- `/api/v1/users/me` requires `profile.read`

Still to be finalized separately:

- access-token lifetime policy
- authorization-code lifetime policy
- clock-skew policy
- consent policy
- whether ADMIN also needs AUTHOR for specific Notes policies
- final AWS/public URLs and deployment topology

Do not silently invent pending values in Notes Service or API Gateway.

## 8. Change Rule

If OAuth claims, scopes, issuer strategy, API audience, or gateway-visible API paths change, update this canonical contract first (or in the same change/PR) and then update consuming services. This file contains no passwords, private keys, authorization codes, access tokens, or other secrets.
