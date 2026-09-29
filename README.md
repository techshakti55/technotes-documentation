# TechNotes documentation

Start here for the first public Notes release. This repository records design and API contracts; source code lives in separate service/UI repositories. Documentation is not proof that code is implemented.

## Build now: first-live release

1. [Scope, owners and integration order](docs/first-live/README.md)
2. [User/OAuth endpoint contract](docs/first-live/oauth.md) - Shakti; PostgreSQL
3. [Notes endpoint contract](docs/first-live/notes.md) - Developer 2; MongoDB
4. [React UI integration mapping](docs/first-live/ui-integration.md)

Published PUBLIC notes are readable anonymously. Only the privately provisioned owner creates content in this release. The paths and response shapes above are frozen until both backend owners and UI update the contract together.

## Service and product map

| Area | Current contract | Broader design |
| --- | --- | --- |
| User/OAuth | [First live](docs/first-live/oauth.md), [printable one-page endpoints](docs/first-live/oauth-endpoints-one-page.pdf) | [Blueprint](docs/services/oauth/engineering-blueprint.md), [v1 reference](docs/services/oauth/reference/spec-v1.md), [structure quickref](docs/services/oauth/reference/structure-quickref.pdf) |
| Notes | [First live](docs/first-live/notes.md) | [Blueprint](docs/services/notes/engineering-blueprint.md), [v1 reference](docs/services/notes/reference/spec-v1.md), [structure quickref](docs/services/notes/reference/structure-quickref.pdf) |
| UI | [Integration](docs/first-live/ui-integration.md) | [UI blueprint](docs/product/ui-blueprint.md) |
| Whole product | [Release scope](docs/first-live/README.md) | [Product blueprint](docs/product/product-blueprint.md), [future Post/Blog](docs/future/post-blog-service.md), [Blog structure quickref](docs/future/post-blog-structure-quickref.pdf) |

## Working practices

- [Git and PR workflow](docs/development/git-workflow.md)
- [Environment strategy](docs/development/environment-strategy.md)
- [Team ownership](docs/development/team-ownership.md)
- [Historical Jira planning](archive/project-management/README.md)

**Precedence:** first-live Markdown contracts > printable summaries > engineering blueprints > earlier v1 specs and historical planning. A quickref may name classes or later functionality that is not in the current release. Verify code in the actual repositories before calling a feature complete.
