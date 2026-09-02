# TechNotes Project HQ

> Central project status and engineering coordination page for technotes.co.in.

## 1. Purpose

This file is the high-level project control page. Jira remains the source of truth for work items and status, GitHub remains the source of truth for code/branches/PRs, and this documentation repository remains the source of truth for architecture and engineering decisions.

## 2. Working Modes

- **Developer Mode**: Jira ticket -> feature branch -> implementation -> tests -> commit -> push -> PR to `develop` -> In Review.
- **Lead/Admin Mode**: planning -> assignment -> architecture decisions -> PR review -> merge -> release -> production readiness.

## 3. Technology Baseline

- Java 21
- Spring Boot 3.5.x baseline
- Spring Cloud 2025.0.x baseline
- Maven
- MongoDB for Notes persistence
- MinIO for local object storage (planned)
- Elasticsearch for search (planned)
- Eureka for service discovery
- Spring Cloud Config Server
- API Gateway
- Pure HTML/CSS/JS in Phase 1; React migration later
- Docker / Docker Compose later in local integration
- AWS production-like deployment later

## 4. Current Service Map

| Service | Purpose | Current State |
|---|---|---|
| Eureka Server | Service discovery | Initial foundation complete |
| Config Server | Central configuration | Initial foundation complete |
| API Gateway | External routing/gateway | Initial foundation complete |
| Notes Service | Core note/content management | Active development |
| Auth Service | Authentication / authorization | Planned |
| User Service | User/profile management | Planned |
| File Service | PDF/image/object storage integration | Planned |
| Search Service | Elasticsearch indexing/search | Planned |

## 5. Current Jira Snapshot

### Completed Infrastructure

- TECH-6 - Platform Infrastructure Foundation - Done
- TECH-7 - Set up Eureka Discovery Server - Done
- TECH-8 - Set up Spring Cloud Config Server - Done
- TECH-9 - Set up API Gateway - Done

### Notes Management

- TECH-10 - Notes Management - To Do
- TECH-11 - Set up Notes Service project baseline - In Progress
- TECH-12 - Configure MongoDB for Notes Service - To Do
- TECH-13 - Design Note domain and MongoDB document model - To Do
- TECH-14 - Create Note API - To Do
- TECH-15 - Read Notes API - To Do
- TECH-16 - Update Note API - To Do
- TECH-17 - Delete Note API - To Do

### Engineering Workflow

- TECH-18 - Establish GitHub team workflow standards - To Do
- TECH-19 - Complete GitHub repository admin controls - To Do

Note: TECH-1 through TECH-5 are Atlassian onboarding/sample items and should not be treated as TechNotes product backlog.

## 6. Notes Service Direction

Initial content hierarchy:

`Category -> Subcategory/Topic -> Note -> Tags`

Example:

`Java -> Core Java -> Language Fundamentals -> Identifiers -> Java Identifiers Complete Guide`

Notes will support long-form technical documentation. Markdown is the planned editable source of truth. PDFs and images will be stored outside the Notes database through the File Service/object storage and referenced by IDs. Search will be integrated later through Elasticsearch.

## 7. Git Standard

- `main` = production-approved code
- `develop` = integration branch
- `feature/TECH-...` = feature/task work
- `fix/TECH-...` = bug fixes
- `docs/TECH-...` = documentation work
- Normal flow: Jira -> branch -> code -> commit -> push -> PR -> review -> merge into `develop`
- Release flow: `develop` -> release PR -> `main`

Commit examples:

- `feat: TECH-14 create note API`
- `fix: TECH-25 correct gateway route`
- `docs: TECH-18 document GitHub workflow`

## 8. Documentation Standard

Each microservice should maintain documentation covering:

- purpose and scope
- ownership
- architecture
- dependencies and technology versions
- configuration
- domain model
- database collections/tables and indexes
- API contracts
- validation and error handling
- service integrations
- security
- logging/metrics/health
- testing
- local run instructions
- deployment
- production readiness/runbook
- architecture decision records (ADRs)

## 9. Architecture Decision Record Index

Planned initial ADRs:

- ADR-001: MongoDB for Notes persistence
- ADR-002: Markdown as note content source of truth
- ADR-003: File binaries stored outside Notes database
- ADR-004: MinIO for local object storage
- ADR-005: Elasticsearch for search
- ADR-006: Eureka for service discovery
- ADR-007: GitHub `main` / `develop` / feature branch strategy

## 10. Production Gate

A service is not production-ready until the agreed checklist passes for code quality, Git/PR review, build/tests, API behavior, database design, security, observability, configuration/secrets, resilience, Docker/deployment, rollback, documentation, and operational readiness.

## 11. How to Use ChatGPT With This Project

Start service conversations with one mode and one ticket, for example:

`Developer Mode - TECH-12. Read current Jira context and Notes architecture. Guide me one step at a time.`

For project-level planning use:

`Lead/Admin Mode - Review project status and recommend next priorities.`

Important design decisions should be copied from conversation into this documentation repository; chat history is not the permanent source of truth.

## 12. Immediate Next Engineering Sequence

1. Complete and review TECH-11 Notes Service baseline.
2. Start TECH-12 MongoDB configuration.
3. Finalize TECH-13 Category/Note MongoDB model before CRUD implementation.
4. Implement TECH-14 through TECH-17 one ticket/branch/PR at a time.
5. Add File Service and Search Service only after the Notes core model/API is stable.
