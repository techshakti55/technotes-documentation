# TechNotes Contribution Guide

## Branch Strategy

- `main`: stable/release-ready code and documentation.
- `develop`: integration branch for approved work.
- `feature/TECH-<id>-<short-name>`: feature development.
- `bugfix/TECH-<id>-<short-name>`: non-production bug fixes.
- `hotfix/TECH-<id>-<short-name>`: urgent production fixes.
- `docs/TECH-<id>-<short-name>`: documentation-only work.
- `chore/TECH-<id>-<short-name>`: engineering maintenance.

Create task branches from the latest `develop` unless a hotfix specifically requires `main`.

## Developer Start

```bash
git switch develop
git pull origin develop
git switch -c feature/TECH-14-create-note-api
```

## Commit Convention

Use Conventional Commit-style messages and include the Jira key when practical.

```text
feat: implement create note API [TECH-14]
fix: handle missing note [TECH-15]
docs: update developer workflow [TECH-18]
chore: configure repository standards [TECH-18]
```

## Push Workflow

```bash
git status
git add .
git commit -m "feat: implement create note API [TECH-14]"
git push -u origin feature/TECH-14-create-note-api
```

After the first push, use `git push` for subsequent commits on the same branch.

## Pull Requests

- Target `develop` for normal feature, bugfix, documentation, and maintenance work.
- Include the Jira issue key in the branch name, commit message, and PR description.
- Complete the PR checklist.
- Do not merge your own PR without review unless an emergency process has been explicitly approved.
- Keep PRs focused on one Jira work item whenever possible.

## Protected Branch Rules

`main` and `develop` should be protected in GitHub. Recommended policy:

- Require a pull request before merging.
- Require at least one approval.
- Dismiss stale approvals when new commits are pushed.
- Require conversation resolution before merge.
- Require status checks after CI is introduced.
- Block force pushes and branch deletion.

## Security

Never commit passwords, API keys, tokens, private certificates, `.env` secrets, or production credentials.
