# Git and pull request workflow

One current guide for TechNotes. During the first-live build, focus on code and tests; use a Jira key only when a real ticket exists.

## Branching and review rules

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


## Practical Windows PowerShell checklist



## Company flow
`Jira -> sync develop -> feature branch -> edit -> status/diff -> add -> staged diff -> commit -> push -> PR -> review -> merge -> sync develop -> cleanup`

## Fresh clone
```powershell
cd D:\TechNotes
git clone https://github.com/<owner>/<repo>.git
cd <repo>
git status
git branch -a
git remote -v
git fetch origin
git switch develop
git pull --ff-only origin develop
git status
```

## Start a Jira ticket
```powershell
git status
git fetch origin
git switch develop
git pull --ff-only origin develop
git switch -c feature/<actual-ticket-key>-short-description
git branch
git status
```

`git switch -c` creates a new local branch from the currently checked-out commit and switches to it.

## Inspect your work
```powershell
git status
git diff
```
- `status`: which files are modified/untracked/staged.
- `diff`: line-by-line unstaged changes.

## Stage only intended files
```powershell
git add docs/development/git-workflow.md
git status
git diff --staged
```
`git add` does **not** upload to GitHub. It places content into the staging area for the next commit.

## Commit
```powershell
git commit -m "docs: <actual-ticket-key> add Git branch and PR workflow guide"
git status
git log --oneline -5
```
A commit is a local history snapshot. It is still only on your laptop.

## Push
```powershell
git push -u origin feature/<actual-ticket-key>-short-description
```
- `push`: upload local commits to GitHub.
- `-u`: set upstream tracking for this branch.
- later pushes can normally be `git push`.

## Pull Request
Create on GitHub:
- base: `develop`
- compare: `feature/<actual-ticket-key>-short-description`
- title: `<actual-ticket-key>: Add Git branch and PR workflow guide`
- description: Summary / Validation / Jira key

**PR is not `git pull`.** PR is a review/merge request on GitHub. `git pull` is a local command.

## Review changes
If changes are requested:
```powershell
# edit
git status
git diff
git add <files>
git diff --staged
git commit -m "docs: <actual-ticket-key> address PR review comments"
git push
```
The same PR updates automatically.

## After merge
```powershell
git switch develop
git fetch origin
git pull --ff-only origin develop
git status
git branch -d feature/<actual-ticket-key>-short-description
```

## Mental model
- CLONE = first local copy
- FETCH = refresh remote knowledge
- SWITCH = change branch
- DIFF = inspect
- ADD = stage
- COMMIT = local snapshot
- PUSH = send commits to GitHub
- PR = review/merge request
- PULL = bring remote changes into local branch


Examples are study material. Check the actual repository, branch and status before running a command. Never invent a Jira key.
