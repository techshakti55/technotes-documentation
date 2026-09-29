# TechNotes.co.in — UI Product Blueprint v1

**Date:** 29 September 2026  
**Status:** Product and experience proposal for team review  
**Companion:** `TechNotes_Backend_Product_Blueprint_v2.md`

## 1. The website in one minute

TechNotes helps a learner move from a topic such as **Java → Core Java → Collections → ArrayList** to a readable explanation, working code and relevant interview Q&A. Visitors can sample useful public material. Registration unlocks more free lessons and community blogging. One Premium plan unlocks the paid learning library. Official notes are curated by authors/reviewers; community blogs have their own review workflow.

The UI must show value before asking for login, make access rules obvious and preserve the user's place after sign-in or checkout. This is a **screen and behavior specification**, not a pixel-perfect design or a claim that APIs already exist.

## 2. Navigation and information architecture

| Main navigation | Destination and purpose |
|---|---|
| Learn | Java and DSA category explorer, official notes and learning paths. |
| Interview Prep | Topic-wise Q&A; filters for topic and difficulty once modeled. |
| Blogs | Published community writing and author pages. |
| Premium | One plan, benefits, pricing and subscription status. |
| Search | Search published material when Search phase is implemented; earlier use category navigation. |
| Account | Sign in / sign up; after login: profile, saved items, my blogs, subscription, sign out. |

Contributor navigation is role-based: `AUTHOR` sees **My Notes**, `REVIEWER` sees **Review Queue**, `ADMIN` sees **Administration**. A normal free user sees **My Blogs** but does not gain curated-note author rights. Navigation visibility improves usability; the backend must independently enforce all permissions.

### Core URLs (proposed, not backend API paths)

`/`, `/learn`, `/learn/:categoryPath`, `/notes/:slug`, `/interview`, `/interview/:slug`, `/blogs`, `/blogs/:slug`, `/blogs/new`, `/my/blogs`, `/premium`, `/account`, `/saved`, `/author/notes`, `/review`, `/admin`, `/auth/callback`.

Use stable canonical slugs and shareable URLs. Redirect back to the originally requested page after authentication. Unknown slugs get a helpful 404; archived/unpublished material does not leak its body.

## 3. Screen inventory and behavior

| Screen | Primary content and actions | Access / phase |
|---|---|---|
| Home | Clear value proposition; Java, DSA and Interview Prep entrances; a few free featured lessons; recent approved blogs; Premium explanation. | Public / public-learning phase |
| Learn catalogue | Category tree, breadcrumbs, topic cards, counts where available; public/free/Premium labels. | Public, safe metadata only |
| Category detail | Child topics, note cards, sorting/filtering and pagination; no enormous preloaded tree. | Public metadata; content gated by tier |
| Note reader | Title, summary, Markdown/code blocks, table of contents, breadcrumbs, related Q&A, reading progress and access state. | Published material according to tier |
| Interview Prep | Q&A cards, topic/difficulty filters, answer page and related notes; gated answers follow same policy. | Curated-content extension |
| Blogs feed/detail | Approved posts, author, publication date, tags, safe formatted body. | Public approved blogs |
| Sign in / registration | OAuth browser flow, clear errors, return destination; no passwords stored in React state beyond input lifetime. | Public / identity phase |
| Account dashboard | Profile, saved items, own blog status and Premium status; concise next actions. | Signed in; some modules phased |
| Blog editor | Title, summary, category/tags, Markdown editor and preview, save draft, submit, validation and review-status timeline. | Signed-in user / community phase |
| My Blogs | Draft, in review, rejected, published and archived tabs; rejection feedback and edit/resubmit. | Owner only |
| Author Notes | Official draft list, create/edit, submit; ETag conflict handling and status. | AUTHOR / editorial phases |
| Review Queue | Separate official-note and community-blog queues; preview, feedback, publish/reject actions. | REVIEWER/ADMIN |
| Premium | One plan and benefits, eligibility, authenticated checkout, pending/active/expired/cancelled status. | Premium phase |
| Administration | Taxonomy management, permitted identity and editorial controls; audit hints. | ADMIN; phase dependent |

## 4. Three access experiences

| Content tier | Anonymous visitor | Free account | Active subscriber |
|---|---|---|---|
| PUBLIC | Full published body | Full | Full |
| FREE_ACCOUNT | Safe preview and sign-in action | Full | Full |
| PREMIUM | Safe preview and plan action | Safe preview and upgrade action | Full while entitlement remains valid |

Cards show the tier clearly (`Free`, `Sign in to read`, `Premium`). A preview contains title, summary, learning outcomes and a deliberately authored sample, never a truncated full paid response delivered to the browser. For blog launch, approved community blogs are public. If a subscription expires while a reader is open, the next protected fetch checks entitlement and presents a clear upgrade/renew state.

## 5. Important user journeys

### Visitor discovers Java content

Home → Learn → Java → Core Java → Collections → ArrayList → public note. Category breadcrumbs and the next lesson keep orientation. A restricted lesson shows its value and its access requirement; sign-in returns the user to that lesson.

### Free learner tries Premium content

Learner opens a Premium card → sees summary, outcomes and plan benefits → selects the single plan → provider checkout → returns to a **verifying payment** state → backend confirms active entitlement → UI refetches access and displays the full published body. A checkout return alone never shows paid content.

### Registered user publishes a blog

Account → My Blogs → New Blog → edit and preview → save draft → submit for review → view status → if rejected, see feedback, revise and resubmit → if approved, public blog detail is shareable. A published edit creates a new review submission while the prior approved version stays live.

### Official author and reviewer

AUTHOR creates an official note draft in My Notes → saves → submits. REVIEWER opens a separate review queue → checks content → provides rejection feedback or publishes. The UI presents API errors, validation and version conflicts without losing unsaved writing.

## 6. Design system direction

- **Visual tone:** Calm technical publication with generous spacing, strong typography and restrained accent color. Avoid a crowded dashboard or excessive gradients.
- **Layout:** Desktop reading view: left category navigation, centered article column, right contents/related topics. Collapse sidebars on smaller screens; keep code blocks horizontally scrollable on mobile.
- **Reading:** Comfortable line length, clear heading hierarchy, syntax-highlighted code with copy button, callouts for mistakes and interview tips, accessible contrast, dark mode as a later enhancement.
- **Feedback:** Skeletons for loading, helpful empty states, inline form validation, clear permission/paywall messages, retry for transient errors, success status after save/submit.
- **Accessibility:** Keyboard navigation, visible focus, semantic headings and landmarks, descriptive labels, mobile tap targets, accessible dialogs; do not convey access only by color.
- **Performance:** Paginated lists and lazy category children, route-level loading, image sizing, efficient code highlighting; avoid fetching private bodies in public pages.

### First design review deliverables

Create wireframes for Home, Learn tree, Note reader in all three access states, Blog editor/status, Review Queue, Premium/checkout status and mobile reader. Agree typography, spacing, colors, buttons, cards and form states before building every screen. The UI should be demonstrated with realistic Java/DSA sample content, not lorem ipsum.

## 7. Frontend architecture and API integration

- React frontend with routes, a reusable layout, content cards, Markdown reader, editor, access banner and form controls. Keep API calls in dedicated clients rather than components.
- OAuth2 Authorization Code + PKCE for browser login according to the User/OAuth spec. The precise browser token-handling approach needs security review before implementation; do not place long-lived secrets in local storage.
- A central session/access context reads identity and the current entitlement from their owners. Render only what the API authorizes; a role-based hidden button is not access control.
- Use an environment-specific API base URL. Local proposal: React `http://localhost:5173`, Gateway `http://localhost:8080`, issuer `http://localhost:9000`; reconcile issuer and container URLs in integration.
- Standard states per data view: loading, loaded, empty, validation error, unauthorized, forbidden, not found and unavailable. Preserve return routes and typed form drafts across login where safe.
- For edits, send the latest ETag in `If-Match`; if another edit wins, explain the conflict and let the user compare/reload before retrying.
- User-generated Markdown must be sanitized at rendering; code snippets are displayed as text and never executed in the browser. Secure image URLs and avoid exposing private content in HTML metadata.

## 8. UI-to-backend mapping

| UI module | Backend dependency | Contract state |
|---|---|---|
| Auth/account | User/OAuth registration, `/api/v1/users/me`, OAuth/OIDC endpoints | Existing proposed spec, implementation to verify |
| Taxonomy and official editor | Notes categories and draft note endpoints | Existing proposed M1 spec |
| Official review and public reading | Notes workflow, revisions and public APIs | Existing proposed M2 spec |
| Free/Premium note access | Notes access-tier migration + Subscription entitlement | New design and APIs required |
| Blog feed/editor/moderation | Blog Service | New design and APIs required |
| Interview Q&A | Curated content extension | New content/API contract required |
| Premium checkout/account | Subscription/Billing + provider | New design and APIs required |
| Saved reading | User-owned references, owner to decide | Proposed extension |
| Search | Search Service or initial category filter | Later phase |

Do not hard-code mock responses as if they were live services. Mock data is useful for UI design but must be visibly marked and replaced behind a documented API contract. Backend and UI teams should review DTO examples together before each feature branch.

## 9. Build order and acceptance checks

1. **Foundation:** Navigation, typography, layouts, route/error states, realistic sample content and responsive wireframes.
2. **Core identity and drafts:** Login/account, category tree, official author screens; real-token API integration.
3. **Public learning:** Published Notes reader, public and free-account states, readable mobile layout and review UI.
4. **Community and Q&A:** Blog feed/editor/review flow and interview prep pages once contracts exist.
5. **Premium:** Plan, checkout, pending verification, entitlement-aware reader and expiry states.
6. **Discovery:** Search, saved reading and refinements after core flows work.

Acceptance scenarios: anonymous user can complete a public lesson; login returns to the intended free lesson; a free user cannot obtain a Premium body by direct API request; a user cannot edit someone else's draft; blog submission is invisible publicly until approved; a reviewer can reject with feedback; payment-pending does not grant access; mobile code blocks remain usable; keyboard users can reach and operate essential controls.

## 10. Open design decisions

- Which Java/DSA lessons are PUBLIC versus FREE_ACCOUNT versus PREMIUM, and how much preview is editorially authored?
- Exact blog categories, moderation guidance and author profile fields.
- Whether interview answers have code execution, quizzes or progress tracking; these are **not** in the initial Q&A scope.
- Single Premium plan billing interval, pricing, cancellation/refund copy and provider experience.
- Whether bookmarks/read progress are stored per user in an existing service or a later dedicated capability.
- Brand assets and final visual language, guided by reviewed wireframes and content examples.

## 11. Sources and relationship to other documents

This blueprint uses the 28 Sep 2026 Notes and User/OAuth service specifications and the 29 Sep 2026 product discussion. It aligns with `TechNotes_Backend_Product_Blueprint_v2.md`. Earlier Notes technical design contains a separate topics model; the newer Notes spec proposes one recursive category tree. Use the latter as the working UI model pending team sign-off. Presentation slides should be prepared **after** these blueprints are reviewed, using the same service names, phases and statuses.
