# TechNotes — Jira vs GitHub

## 1. Why We Use Both

TechNotes uses Jira and GitHub for different responsibilities.

- **Jira manages the work.**
- **GitHub manages the source code and code-review lifecycle.**

They complement each other; one does not replace the other in our company-style workflow.

---

## 2. Jira — What It Does

Jira is our central project-management and work-tracking system.

We use Jira for:

- Product/project backlog
- Epics
- Stories
- Development tasks
- Bugs
- Sprint planning
- Priority
- Assignee / ownership
- Work status
- Acceptance criteria
- Estimates/story points when introduced
- Team progress tracking
- Release planning

Example lifecycle:

```text
Backlog
  ↓
To Do
  ↓
In Progress
  ↓
Code Review
  ↓
Testing
  ↓
Done
```

Example Jira ticket:

```text
TECH-201: Implement Create Note API

Type: Story
Priority: High
Assignee: Developer
Status: In Progress
Service: Notes Service
```

Jira answers questions such as:

- What needs to be built?
- Why are we building it?
- Who owns it?
- What is its priority?
- What is currently in progress?
- What is blocked?
- What is done?

---

## 3. GitHub — What It Does

GitHub is our source-code management and collaboration platform.

We use GitHub for:

- Git repositories
- Source code
- `main`, `develop`, and task branches
- Commit history
- Pull requests
- Code reviews
- Merge workflow
- Tags/releases later
- GitHub Actions/CI later

Example branch:

```text
feature/TECH-201-create-note
```

Example commit:

```text
feat: TECH-201 implement create note API
```

Example pull request:

```text
TECH-201: Implement Create Note API

feature/TECH-201-create-note
        ↓
develop
```

GitHub answers questions such as:

- Where is the code?
- What changed?
- Who changed it?
- Which branch contains the work?
- Has the code been reviewed?
- Has it been merged?

---

## 4. Jira vs GitHub

| Area | Jira | GitHub |
|---|---|---|
| Primary purpose | Project/work management | Source-code management |
| Backlog | Yes | Possible, but Jira is our primary system |
| Epic/Story/Task/Bug | Primary | Not primary in TechNotes |
| Sprint planning | Yes | Not our primary tool |
| Priority/ownership | Yes | Limited/project dependent |
| Source code | No | Yes |
| Git branches | No | Yes |
| Commits | No | Yes |
| Pull requests | No | Yes |
| Code review | No | Yes |
| Merge | No | Yes |
| CI/CD | Tracks work around it | GitHub Actions can execute it |

---

## 5. TechNotes Company Workflow

```text
Requirement
    ↓
Jira Epic / Story / Task / Bug
    ↓
Ticket assigned to developer
    ↓
Developer moves ticket → In Progress
    ↓
Create Git branch using Jira key
    ↓
Development + tests
    ↓
Commit using Jira key
    ↓
Push branch to GitHub
    ↓
Create Pull Request → develop
    ↓
Code Review
    ↓
Testing
    ↓
Merge
    ↓
Jira ticket → Done
```

Example:

```text
Jira
TECH-201: Implement Create Note API

        ↓

GitHub Branch
feature/TECH-201-create-note

        ↓

Commit
feat: TECH-201 implement create note API

        ↓

Pull Request
TECH-201: Implement Create Note API

        ↓

develop

        ↓

Jira
TECH-201 → Done
```

---

## 6. TechNotes Rule

From the Jira adoption point onward:

> Jira is the source of truth for engineering tickets.

Each microservice keeps its own GitHub repository, but developers do not need separate disconnected ticket systems for every repository.

A Jira ticket key must be used consistently in branch names, commits, and pull requests so project-management work can be traced to code changes.

---

## 7. Responsibility Boundary

Remember this simple rule:

```text
JIRA
WHAT + WHY + WHO + PRIORITY + STATUS

GITHUB
CODE + BRANCH + COMMIT + PR + REVIEW + MERGE
```

Together:

```text
Jira Ticket
    ↓
GitHub Branch
    ↓
Code
    ↓
Commit
    ↓
Pull Request
    ↓
Review
    ↓
Merge
    ↓
Jira Done
```

This is the baseline TechNotes engineering workflow. We will expand it later with sprint planning, CI/CD, testing gates, releases, deployment, and monitoring as the project reaches those stages.
