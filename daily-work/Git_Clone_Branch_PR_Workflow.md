# Git Clone, Feature Branch & Pull Request Workflow

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
git switch -c feature/TEC-14-git-workflow-guide
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
git add doc/daily-work/Git_Clone_Branch_PR_Workflow.md
git status
git diff --staged
```
`git add` does **not** upload to GitHub. It places content into the staging area for the next commit.

## Commit
```powershell
git commit -m "docs: TEC-14 add Git branch and PR workflow guide"
git status
git log --oneline -5
```
A commit is a local history snapshot. It is still only on your laptop.

## Push
```powershell
git push -u origin feature/TEC-14-git-workflow-guide
```
- `push`: upload local commits to GitHub.
- `-u`: set upstream tracking for this branch.
- later pushes can normally be `git push`.

## Pull Request
Create on GitHub:
- base: `develop`
- compare: `feature/TEC-14-git-workflow-guide`
- title: `TEC-14: Add Git branch and PR workflow guide`
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
git commit -m "docs: TEC-14 address PR review comments"
git push
```
The same PR updates automatically.

## After merge
```powershell
git switch develop
git fetch origin
git pull --ff-only origin develop
git status
git branch -d feature/TEC-14-git-workflow-guide
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
