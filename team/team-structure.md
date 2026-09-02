# Team Structure

## Team Model

TechNotes is currently organized as a small three-member product engineering team. The team should work with clear ownership while avoiding knowledge silos.

## Role 1 — Technical Lead / Product Engineering Lead

Primary responsibilities:

- Own overall architecture and technical direction.
- Approve major design decisions and ADRs.
- Break work into deliverable tasks.
- Review high-impact pull requests.
- Coordinate release readiness.
- Maintain engineering standards.
- Ensure security, reliability, and cost considerations are addressed.

## Role 2 — Backend / Platform Engineer

Primary responsibilities:

- Implement Spring Boot microservices and APIs.
- Work with databases, messaging, search, and service discovery.
- Maintain Docker and local platform dependencies.
- Write unit/integration tests.
- Contribute to CI/CD and observability.
- Review backend pull requests.

## Role 3 — Frontend / QA-Focused Engineer

Primary responsibilities:

- Implement Phase 1 HTML/CSS/JavaScript UI.
- Integrate frontend with APIs.
- Maintain functional test scenarios and regression checklists.
- Validate API/UI behavior in local and shared environments.
- Contribute to documentation and release validation.

## Shared Responsibilities

All team members are expected to:

- Use feature branches.
- Raise pull requests.
- Participate in reviews.
- Write/update documentation for meaningful changes.
- Never commit credentials or secrets.
- Keep local environment setup reproducible.
- Report blockers early.

## Ownership Principle

A task can have one primary owner, but critical areas should have at least one additional team member capable of reviewing or supporting the work.

## Review Principle

For significant changes, the author should request review from another team member before merge. Architecture, security, production configuration, and database-contract changes should receive Technical Lead review.
