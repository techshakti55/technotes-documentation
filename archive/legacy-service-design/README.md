# Earlier service design documents

These three DOCX files came from the local documentation branch `docs/local-files-review` (commit `b8f5cfb`). They are retained as historical context and are **not** implementation instructions for the first public release.

| File | Contents | Why archived |
| --- | --- | --- |
| [backend-architecture-v1.docx](backend-architecture-v1.docx) | Long-term backend architecture and future Kafka, search, billing and cloud ideas | Broader than the live scope; includes public registration and later integrations. |
| [notes-technical-design-v1.docx](notes-technical-design-v1.docx) | Early Notes design with separate topics, attachment/search integrations and old error/port examples | Conflicts with the current single hierarchical category model and fixed first-live paths. |
| [notes-developer-handoff-v1.docx](notes-developer-handoff-v1.docx) | Older developer startup, Jira TEC-9 and M1 implementation instructions | Branch/ticket/baseline state can change; later first-live release includes publication. |

The source branch also held exact duplicate DOCX copies (`(3)`/`(4)` technical design; handoff with/without `(1)`). Only one copy of each is retained. Its OAuth structure quickref and two-service API PDF repeated material already present in [OAuth structure](../../docs/services/oauth/reference/structure-quickref.pdf) and the [first-live contract](../../docs/first-live/README.md), so no extra binary copies were added.

**Use instead:** [first-live release](../../docs/first-live/README.md), [OAuth contract](../../docs/first-live/oauth.md), [Notes contract](../../docs/first-live/notes.md), then the [service blueprints](../../README.md#service-and-product-map). If these archived documents disagree, the first-live Markdown contracts win.
