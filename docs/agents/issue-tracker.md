# Issue tracker: Local markdown + Kandev board

Tickets and specs are local markdown files. The Kandev board (http://127.0.0.1:38429, workspace `taipei-city-dashboard`) is a pointer layer only. Do not use GitHub Issues. Never `git push` or open PRs against upstream unless the user explicitly says so.

## Conventions

- One feature per directory: `.scratch/<feature-slug>/`
- The spec is `.scratch/<feature-slug>/spec.md`
- Implementation tickets are one file each at `.scratch/<feature-slug>/issues/<NN>-<slug>.md`, numbered from `01`, never a single combined file
- Each ticket has a `Status:` line (the role strings in `triage-labels.md`, plus `claimed` and `resolved`) and a `Blocked by:` line listing ticket numbers
- Comments and conversation history append to the bottom of the file under `## Comments`
- Never put secrets in these files (AGENTS.md rule 4)

## Kandev cards

- Each ticket has exactly one Kandev card. The card description contains only the ticket's file path (relative to the repo root), never a copy of its content.
- The file is the source of truth; the card is only a pointer.
- Claim: start a Kandev session on the card, then set `Status: claimed` in the file before any work.
- Resolve: append the answer to the file, set `Status: resolved`, and move the card to Done.

## When a skill says "publish to the issue tracker"

Create the file under `.scratch/<feature-slug>/` (create the directory if needed), then create its Kandev card whose description is only that file's path.

## When a skill says "fetch the relevant ticket"

Read the file at the referenced path. The user will normally pass the path or the ticket number.

## Wayfinding operations

Used by `/wayfinder`.

- **Map**: `.scratch/<effort>/map.md` (Destination / Notes / Decisions so far / Not yet specified / Out of scope).
- **Child ticket**: `.scratch/<effort>/issues/NN-<slug>.md`, with a `Type:` line (`research`/`prototype`/`grilling`/`task`) and a `Status:` line (`claimed`/`resolved`).
- **Blocking**: a `Blocked by: NN, NN` line near the top. A ticket is unblocked when every file it lists is `resolved`.
- **Frontier**: scan `.scratch/<effort>/issues/` for files that are open, unblocked and unclaimed; lowest number first.
- **Claim**: set `Status: claimed` and save before any work.
- **Resolve**: append the answer under `## Answer`, set `Status: resolved`, then append a context pointer (gist + link) to the map's Decisions-so-far.
