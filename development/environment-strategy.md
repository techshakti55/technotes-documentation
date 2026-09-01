# Environment Strategy

## Environments

TechNotes uses three logical environments.

### Local
Used by each developer on their own machine.

- Spring Boot services run from IntelliJ or Docker.
- Shared dependencies such as MongoDB, MinIO, Elasticsearch, and supporting platform services run through Docker Compose where practical.
- Local configuration must never contain production secrets.

### Dev
Shared integration environment used to validate changes after local testing.

- Represents the combined work of the team.
- Deployments come from reviewed branches or the integration branch.
- Data is non-production test data.

### Prod
Customer-facing production-like/production environment.

- Initial deployment target: AWS EC2 with Docker Compose.
- Only reviewed and release-approved changes are deployed.
- Secrets are stored outside Git.
- Backups and rollback procedures are required.

## Spring Profiles

Recommended profiles:

```text
local
dev
prod
```

Application code should not contain hard-coded environment URLs, credentials, ports, bucket names, or database passwords.

## Configuration Ownership

Configuration should be externalized through Spring Cloud Config and environment variables. Sensitive values must not be committed to the documentation or source repositories.

## Promotion Model

```text
Developer local validation
        -> Pull Request
        -> develop / Dev validation
        -> release approval
        -> main / Production deployment
```

## Production Principle

The same application artifact should be promoted between environments wherever possible. Environment differences should come from configuration, not separate source-code branches containing different application logic.
