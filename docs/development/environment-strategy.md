# Environment strategy

The first-live application has local development and a future HTTPS production deployment. Exact AWS runtime and DNS choices remain deployment decisions.

| Environment | Purpose | Rules |
| --- | --- | --- |
| Local | Developers run UI and services | Proposed defaults: React :5173, Gateway :8080, issuer :9000, Notes :8081; isolated PostgreSQL/MongoDB; no committed secrets. |
| Dev | Shared integration when available | Test data and identities; reviewed code and stable configuration. |
| Prod | Public website | HTTPS; exact issuer/redirect/CORS; durable databases, external secrets, backup/restore and rollback evidence. |

Profiles local/dev/prod may be used consistently. Keep configuration out of code. The OAuth issuer string must match what resource servers validate. Promote the same artifact with environment-specific configuration where practical. Config Server and Eureka are platform dependencies only where the deployed topology uses them.

The UI is React/Vite in the first-live project. Production domain, AWS compute, certificates and DNS will be recorded after a deployment decision and verification.
