# Git Workflow

## Purpose

This document defines the Git branching and pull request workflow for the TechNotes team.

## Permanent Branches

### `main`
Production-ready documentation and release-level changes only.

### `develop`
Integration branch for reviewed work that is ready for the next release.

## Working Branches

Create short-lived branches from `develop`.

- `feature/<name>` — new feature or documentation work
- `bugfix/<name>` — non-production bug fixes
- `hotfix/<name>` — urgent production fixes, normally branched from `main`
- `chore/<name>` — maintenance, tooling, cleanup
- `docs/<name>` — documentation-only changes

Examples:

```text
feature/note-service-api
docs/local-setup
bugfix/login-validation
hotfix/prod-config
```

## Standard Flow

```text
develop
  -> feature/...
  -> commit
  -> push
  -> pull request to develop
  -> review
  -> approval
  -> merge
```

Release flow:

```text
develop -> release validation -> main
```

## Rules

1. Do not develop directly on `main`.
2. Avoid direct development on `develop`.
3. Every meaningful change should have a pull request.
4. Keep pull requests focused and reasonably small.
5. Pull requests must include a clear summary and testing/validation notes.
6. Resolve review comments before merge.
7. Delete short-lived branches after merge when no longer needed.

## Commit Message Convention

Use a simple Conventional Commits style:

```text
feat: add note search endpoint
fix: handle invalid category id
docs: add local environment guide
chore: update docker compose configuration
refactor: simplify note mapper
test: add note service unit tests
```

## Hotfix Flow

For urgent production fixes:

```text
main
  -> hotfix/<name>
  -> PR to main
  -> merge
  -> synchronize the same fix back into develop
```

## Pull Request Ownership

The author must not treat their own code as automatically approved. At least one available team member should review significant changes whenever practical.
