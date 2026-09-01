# TechNotes Developer GitHub Flow

This document defines the standard GitHub workflow every TechNotes developer must follow for backend service development.

## 1. Repository Model

Each microservice is maintained in a separate GitHub repository.

Initial repositories:

- `technotes-eureka-server`
- `technotes-config-server`
- `technotes-api-gateway`

Additional services will follow the same naming pattern, for example `technotes-auth-service`, `technotes-user-service`, and `technotes-notes-service`.

The `technotes-documentation` repository is used for engineering documentation, standards, architecture decisions, and team workflow documentation.

## 2. Local Workspace

Every developer should create one parent folder on the laptop and keep all TechNotes repositories inside it.

Example on Windows:

```text
D:\TechNotes\
├── technotes-eureka-server
├── technotes-config-server
├── technotes-api-gateway
└── technotes-documentation
```

Each folder is an independent Git repository.

## 3. Required Developer Tools

Before starting development, each developer must have:

- Java 21
- IntelliJ IDEA
- Git
- Maven
- Docker Desktop
- Postman

Developers should verify versions before beginning assigned work.

Example commands:

```bash
java -version
git --version
mvn -version
docker --version
```

## 4. Repository Access

The Technical Lead creates the repository and adds required developers as collaborators with appropriate write access.

Developers must never share GitHub passwords, tokens, private keys, or credentials in source code or chat.

## 5. Standard Branch Model

Every service repository follows this branch structure:

```text
main
  ↓
develop
  ↓
feature/TECH-XXX-task-name
```

### `main`

Production/release-approved code only.

### `develop`

Integrated development branch. Completed and reviewed feature work is merged here.

### `feature/*`

Temporary branch used by a developer for one assigned task.

Examples:

```text
feature/TECH-101-eureka-server
feature/TECH-102-config-server
feature/TECH-103-api-gateway
```

Developers must not develop directly on `main` or `develop`.

## 6. First-Time Repository Setup for a Developer

After repository access is granted, clone the assigned repository.

```bash
git clone <repository-url>
cd <repository-folder>
```

Check available branches:

```bash
git branch -a
```

Switch to the shared development branch:

```bash
git checkout develop
git pull origin develop
```

Create the task branch from the latest `develop`:

```bash
git checkout -b feature/TECH-XXX-task-name
```

Example:

```bash
git checkout -b feature/TECH-101-eureka-server
```

## 7. Daily Development Flow

Before beginning new work on an existing task branch:

```bash
git checkout develop
git pull origin develop
git checkout feature/TECH-XXX-task-name
```

If necessary, synchronize the latest `develop` changes into the feature branch according to the team lead's instructions.

Developers should keep commits small and focused.

## 8. Commit Standard

Use meaningful Conventional Commit-style messages.

Examples:

```text
feat: setup eureka server
feat: configure service registration
fix: correct eureka client configuration
docs: add local run instructions
test: add gateway route test
refactor: simplify config loading
```

Avoid meaningless messages such as:

```text
update
changes
final
working
code fixed
```

## 9. Push the Feature Branch

After local validation:

```bash
git status
git add .
git commit -m "feat: implement assigned service foundation"
git push -u origin feature/TECH-XXX-task-name
```

Never force-push unless the Technical Lead explicitly approves it.

## 10. Pull Request Flow

After completing the assigned task, create a Pull Request:

```text
feature/TECH-XXX-task-name
            ↓
         develop
```

The PR must contain:

- Clear summary of the change
- Related issue/task number
- Testing performed
- Important configuration changes
- Known limitations, if any

When appropriate, reference the GitHub issue using:

```text
Closes #<issue-number>
```

Example:

```text
Closes #3
```

## 11. Code Review

The developer who created the PR does not merge immediately.

Reviewer checks:

- Correct branch and task scope
- Code quality
- Build status
- Configuration
- Secrets or accidental files
- Testing evidence
- README/documentation changes

If changes are requested, the developer fixes the code on the same feature branch, commits, and pushes again. The existing PR updates automatically.

## 12. Merge and Cleanup

After approval, merge the PR into `develop` using the merge method defined by the team.

After successful merge, the feature branch should normally be deleted.

The developer then refreshes local `develop`:

```bash
git checkout develop
git pull origin develop
```

## 13. Release Flow

Normal development:

```text
feature/* → develop
```

After integration testing and release approval:

```text
develop → main
```

Direct feature-to-main pull requests are not allowed unless the Technical Lead explicitly defines an emergency/hotfix workflow.

## 14. TechNotes Initial Ownership

Initial backend service ownership:

- `punambagal9860` → `technotes-eureka-server`
- `singhshakti413` → `technotes-config-server`
- `techshakti55` → `technotes-api-gateway`

Ownership means primary implementation responsibility. Important changes are still reviewed by another team member or the Technical Lead.

## 15. Definition of Done for a Developer Task

A backend task is complete only when:

- Required implementation is complete.
- Application runs locally.
- Maven build passes.
- Required local verification/tests pass.
- No secrets are committed.
- README/config documentation is updated when needed.
- Feature branch is pushed.
- Pull Request is created against `develop`.
- Review feedback is resolved.
- PR is approved and merged.

## 16. Golden Rule

Always work from an assigned issue, create a dedicated branch from the latest `develop`, make focused commits, push the feature branch, and use a reviewed Pull Request to merge back into `develop`.
