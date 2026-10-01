# Ptah workflow rules

Cross-cutting rules the agent applies regardless of which slash command is running. These apply to **every** Ptah command (`/ptah-spec`, `/ptah-design`, `/ptah-implement`, `/ptah-code-review`, `/ptah-fix`, `/ptah-document`).

---

## Always read LOGS.md first

When working on any feature, read `LOGS.md` in the relevant spec folder before doing anything else. It is the single source of truth for current state — what's been done, what was decided, what's next. Never skip it, even when "just looking" at one specific file.

---

## Stop and ask, one question at a time

If anything in the spec or design is ambiguous, contradictory, or underspecified, stop and ask the user a targeted question before proceeding. Ask one question at a time when there are several. Do not guess to keep momentum — guessing accumulates into deviations that surface much later.

This applies before:
- Writing any design (`/ptah-design`)
- Writing any code (`/ptah-implement`)
- Applying any fix (`/ptah-fix`)

If everything is clear, skip the clarifying step entirely and proceed.

> **Note on delegated commands:** `/ptah-design` and `/ptah-implement` run their main work in a subagent, which can't talk to the user. The rule still applies — the subagent returns its questions instead of guessing, and the dispatching command asks them one at a time. See **Delegated work** below.

> **Note on `/ptah-fix` modes:** `/ptah-fix` supports `auto`, `plan`, and `interactive` modes that control verbosity for routine fixes. The stop-and-ask rule applies in **all three** — if a fix is ambiguous, has side effects beyond scope, requires a design change, or introduces a new dependency, the agent stops and asks. `auto` mode does not suppress this rule.

---

## Why the review is isolated

`/ptah-code-review` and `/ptah-review` delegate their actual judgment to a dedicated subagent (`ptah-code-reviewer`, `ptah-reviewer` — see `.claude/agents/ptah/`) rather than running the review in the same conversation as the work being reviewed.

A subagent starts with a blank context. It never sees the implementer's live reasoning, discarded approaches, or self-justifications from mid-session — only what's written to `SPEC.md` / `DESIGN.md` / `IMPLEMENTATION.md` / `LOGS.md` and the code itself. That matters: an agent reviewing its own recent work in the same conversation tends to accept its own rationalizations rather than scrutinize them, even when those rationalizations were never written down anywhere a fresh reader could check them.

Two things follow from this, and both commands (and their subagents) are built around them:

- **The reviewer treats `IMPLEMENTATION.md` and `LOGS.md` as claims, not facts.** Its job is to verify what's written against the actual code and against `SPEC.md` / `DESIGN.md`, not to restate what the implementer said happened.
- **The subagent's tools are read-only** (`Read`, `Grep`, `Glob`). It cannot write `CODE-REVIEW.md` / `REVIEW.md` itself — it returns findings as text, and the dispatching command (`/ptah-code-review` or `/ptah-review`) writes the file. This makes "documentation only, no code changes" an enforced permission boundary rather than just an instruction.

This isolation applies only to the judgment step. `/ptah-fix` runs in the main session and trusts the review's findings rather than re-litigating them — applying a fix should follow what the review already decided, not independently re-derive it.

Isolation also determines where the knowledge base gets consulted for reviews — see "Knowledge discipline" below. Since the dispatching commands pass the subagents nothing beyond a folder path, the subagents read `INDEX.md` themselves, the same way they read `SPEC.md` and `IMPLEMENTATION.md` themselves.

---

## Delegated work

`/ptah-design` and `/ptah-implement` are the two commands that read the most — a whole codebase to explore, or a whole design's worth of code to write — so they run that work in a subagent (`ptah-designer`, `ptah-implementer` — see `.claude/agents/ptah/`) and keep the main session as a thin dispatcher. The goal is a lean main context, not independent judgment (that's what the review subagents are for).

They follow the same contract as the review subagents:

- **The prompt is the folder path, nothing else.** The subagent reads `SPEC.md`, `DESIGN.md`, `LOGS.md`, `refs/`, `CLAUDE.md`, and `INDEX.md` itself. The dispatcher never summarizes the conversation or explains anything on the user's behalf.
- **The subagent returns a result in the shared format** (see **Reports and vocabulary** below); **the dispatcher owns `LOGS.md` and the artifact.** `ptah-designer` returns `DESIGN.md` as text and never writes files. `ptah-implementer` writes code — that's its job — but returns `IMPLEMENTATION.md` as text and never touches `LOGS.md`.

Subagents can't talk to the user, so **Stop and ask** becomes a loop:

1. The subagent hits something it would normally ask about. It stops and returns its questions, each tagged with the change-entry type the answer would be (`decision`, `deviation`, `scope-change`) — result status `needs-input`.
2. The dispatcher logs a `/<command> paused` command entry, then asks the questions one at a time.
3. After each answer, the dispatcher appends a change entry recording it (`Trigger: user-request`, the tagged type, `What:` the answer as a one-line decision).
4. The dispatcher re-dispatches with the same prompt — just the folder path. The subagent finds the answers in `LOGS.md`, where they belong anyway.

Answers go through `LOGS.md` and never through the prompt, so a re-dispatch in a later session — after the main session ended mid-loop — works exactly the same way. And because the pause is a real command entry, `/ptah-status` and `/ptah-resume` show the spec as ⏸️ paused, with what it's blocked on.

Subagents can't spawn subagents, so these stay dispatched from the main session only.

---

## Knowledge discipline

Ptah maintains a persistent, project-wide knowledge base — `.claude/ptah/knowledge/knowledge.db` (SQLite) plus its human-readable mirror `INDEX.md` — separate from any single spec's `LOGS.md`. It exists so a gotcha, convention, or dependency quirk discovered once doesn't have to be rediscovered on the next feature, or the one after that. Full schema and CLI contract: [`guides/knowledge-format.md`](./guides/knowledge-format.md).

### Capture is `/ptah-learn`-only

Nothing gets written to `knowledge.db` automatically. Workflow commands never call `/ptah-learn` on their own behalf, even when they clearly just hit something learn-worthy — capturing is a judgment call the user makes explicitly, which keeps the knowledge base signal instead of noise. If a command notices something that looks worth keeping, it can *suggest* running `/ptah-learn` (see **Suggest capture before hand-off** below), but it never runs it unprompted.

### Suggest capture before hand-off

`/ptah-design`, `/ptah-implement`, `/ptah-fix`, and `/ptah-document` each check, right before handing off, whether the work surfaced anything worth keeping in the knowledge base. The check has to happen before that context is gone:

- `/ptah-design` and `/ptah-implement` do their main work in a subagent (see **Delegated work** above), whose context disappears the moment it returns. So the subagent hands back its candidates in a `### Learn candidates` section of its result, and the dispatching command asks the user about them.
- `/ptah-fix` and `/ptah-document` run in the main session, so they look back over their own session.

A candidate is anything that fits one of the seven categories in [`guides/knowledge-format.md`](./guides/knowledge-format.md) and holds beyond this one feature — non-obvious behavior that cost time to discover, a library or tool quirk, a convention that got settled. Facts specific to this feature aren't candidates; they belong in the spec's own artifacts. Skip anything already in `INDEX.md`.

If there are candidates, ask one at a time:

> "This surfaced `<brief description>`. Worth capturing with `/ptah-learn`?"

If the user agrees, give them a pre-filled invocation to run — `/ptah-learn "<title>" --category <category> --source "/<command> <folder-name>"` — rather than running it yourself. The `--source` matters: by the time the user runs `/ptah-learn`, the command that found it has finished, so `/ptah-learn` can't infer where the finding came from on its own. If the user declines, or nothing qualifies, move on without comment. This check never blocks the hand-off.

### Consulting knowledge is automatic, and cheap by design

Unlike capture, *consulting* the knowledge base is not optional — every workflow command checks it before doing its main work:

- **Main-session commands** (`/ptah-fix`, `/ptah-document`) read `.claude/ptah/knowledge/INDEX.md` directly, early in their own steps, the same way they already read `LOGS.md` first.
- **Subagents** (`ptah-designer`, `ptah-implementer`, `ptah-code-reviewer`, `ptah-reviewer`) read `INDEX.md` themselves, as part of their own Step 1 reading list — *not* something the dispatching command passes in, since that would violate the isolation described above and in **Delegated work** above.

All of them read only `INDEX.md`, never `knowledge.db` directly — `INDEX.md` is titles, categories, tags, and confidence only, deliberately not full entry bodies, so the consult step stays a cheap scan rather than a token-expensive read. Only `/ptah-learn` and `/ptah-recall` invoke `ptah_knowledge.py` for the full entry, a search, or a graph traversal — and only when something on the index scan actually looked relevant.

If `INDEX.md` doesn't exist yet (no `/ptah-learn` has ever run on this project), every consult step skips silently — this is the expected state for a fresh project, not an error.

### Disjoint from LOGS.md — no cross-citation, either direction

Knowledge entries are never cited in any `LOGS.md` entry, and `LOGS.md` content is never written into `knowledge.db`. If something learned from `INDEX.md` changes a decision mid-session, the decision itself gets a normal `LOGS.md` change entry (per "Logging discipline" below) — the knowledge entry is context that informed the decision, not part of the record of what happened. This mirrors the same reasoning as the isolated-review split: two different systems, two different jobs, no blending them.

### `INDEX.md` is disposable

`INDEX.md` is regenerated in full by `ptah_knowledge.py` on every `/ptah-learn` write. It is never hand-edited — any manual edit is silently overwritten on the next write, so there's no reason to make one. If it's ever suspected to have drifted from `knowledge.db` (it shouldn't, since regeneration is automatic), `python3 .claude/ptah/ptah_knowledge.py regenerate-index` rebuilds it without touching any data.

---

## Logging discipline

While working on any spec, append **change entries** to the corresponding `LOGS.md` whenever a meaningful event happens mid-session — not just when a command completes.

### When to log

Log automatically, without asking, on these events (the values are defined in [`guides/vocabulary.md`](./guides/vocabulary.md)):

| Type | Trigger |
|------|---------|
| `decision` | A choice was made that affects the work (library, pattern, structure, naming convention), or the user answered a question |
| `deviation` | The implementation diverged from the spec or design |
| `scope-change` | Something was added to, removed from, or moved out of scope mid-flow |
| `blocker` | Stopped to ask the user, or hit something that needs resolving — outside a subagent question loop, which logs a `paused` command entry instead |
| `correction` | The user pointed out something was wrong, and the agent is redoing it |

### When NOT to log

Routine work creates noise — do not log it:
- Reading files, running searches, asking the next clarifying question in a normal flow
- Fixing typos, formatting, or reformatting code
- Restating something already captured in a command's completion entry
- Internal reasoning steps that don't change anything
- Consulting `INDEX.md` — reading it is routine, same as reading `LOGS.md`; only log if what it surfaced changed a decision (and then log the decision, not the lookup)

### Entry format

```markdown
## <YYYY-MM-DD HH:MM:SS> — change during /<command>
- Trigger: <user-request | agent-decision>
- Type: <decision | deviation | scope-change | blocker | correction>
- What: <one-line description>
- Why: <reason>
- Impact: <files, decisions, or downstream steps affected; or "none">
```

Append to the same `LOGS.md` as command entries, in chronological order. Change entries are the canonical record of mid-flow events — completion entries reference them ("Deviations: yes — see change entries above") rather than restating them.

The full schema for both command and change entries lives in [`guides/logs-format.md`](./guides/logs-format.md).

---

## Reports and vocabulary

Every fixed value in Ptah — command statuses, result statuses, spec states, change types and triggers, severities, verdicts, fix modes — is defined once, in [`guides/vocabulary.md`](./guides/vocabulary.md). Commands and subagents use those values exactly; a value that isn't on its list is an error, never something to coerce.

Every final report follows [`guides/result-format.md`](./guides/result-format.md), in markdown:

- **Subagent → dispatcher:** a `===RESULT===` block whose bullets are the `LOGS.md` fields for the entry it produces, then artifact blocks named after their files, then `===END===`. A result that breaks the format is malformed — the dispatcher logs `failed` and never guesses at or patches it.
- **Command → user:** one hand-off shape for every command — status icon and line, artifact path, one to three key facts, and the next command.

`LOGS.md` entries, results, and hand-offs share the same field names, so information moves between them by copying, not translating.

---

## Spec identifiers

Every spec folder created by `/ptah-spec` is named `ptah-<n>-<slug>`, e.g. `ptah-3-user-login`.

- `<n>` — a sequential integer, unique per project
- `<slug>` — a kebab-case version of the feature name given to `/ptah-spec`

### Assigning a number (`/ptah-spec` only)

The next number lives in `.claude/ptah/ptah.yml` under `specs.next_id` — this is a plain config value, not something the agent works out by scanning `.claude/specs/`.

When `/ptah-spec` creates a new folder:

1. Read `specs.next_id` from `.claude/ptah/ptah.yml`. If the file, or the `specs` section, or the key is missing, treat the next id as `1`.
2. Use that value as `<n>` for the new folder.
3. Immediately after creating the folder, write `specs.next_id: <n + 1>` back to `ptah.yml` — creating the file or the `specs:` section if it didn't exist yet, and leaving any other config (`commands:`, `context_sources:`, etc.) untouched.

The agent never infers the next number from existing folder names. Numbers are never reused, even if a folder is later deleted — the counter only moves forward. If a gap needs reclaiming, that's a manual edit to `specs.next_id`, not something any command does automatically.

(The knowledge base's entry ids follow a related but distinct rule — see "Knowledge discipline" above and `guides/knowledge-format.md`: SQLite's own `AUTOINCREMENT` owns that counter, since there's a real database to keep it in.)

### Resolving an identifier (every other command)

Every command that takes a spec argument — `/ptah-design`, `/ptah-implement`, `/ptah-code-review`, `/ptah-fix`, `/ptah-document`, `/ptah-resume` — accepts any of:

- a bare number: `3`
- a number with the prefix: `ptah-3`
- the full folder name: `ptah-3-user-login`

Resolve the argument in this order:

1. If it matches an existing folder name in `.claude/specs/` exactly, use it.
2. Otherwise, strip a leading `ptah-` if present, take the leading number, and glob `.claude/specs/ptah-<n>-*`. If exactly one folder matches, use it.
3. Otherwise, treat the argument as a literal legacy folder name — `.claude/specs/<argument>/` — for specs that predate this convention.
4. If nothing matches any of the above, stop and tell the user no spec was found for `<argument>`, and suggest running `/ptah-status`.

This is a single lookup for one already-existing folder, not a scan across all of them — it's unrelated to how `/ptah-spec` assigns new numbers above.

### Displaying identifiers

Whenever a command refers to a spec in output shown to the user — `/ptah-resume`'s summary header, or a hand-off message suggesting the next command to run — show **only the number**, e.g. "run `/ptah-design 3`". Never surface the slug or full folder name in these contexts.

Two exceptions:
- **`/ptah-status` rows** show the full spec name (`ptah-3-user-login`), since the report is a scannable overview meant to be read, not typed. Its `next:` line still uses the bare number, since that's the part you'd actually run.
- **File paths** the user is meant to open and review (e.g. "Review it at `.claude/specs/ptah-3-user-login/SPEC.md`") need the real, full path.

---

## Path conventions

| Location | Purpose |
|----------|---------|
| `.claude/skills/ptah-<command>/` | One skill per command, invoked as `/ptah-<command>`. Skills can't nest in a subfolder, so they're namespaced by the `ptah-` prefix instead |
| `.claude/agents/ptah/` | Ptah's subagent definitions — the designer and implementer used by `/ptah-design` and `/ptah-implement`, and the isolated reviewers used by `/ptah-code-review` and `/ptah-review`. See **Delegated work** and **Why the review is isolated** above |
| `.claude/ptah/` | Ptah's config (`ptah.yml`) and reference docs (`RULES.md`, and `guides/`: `vocabulary.md`, `result-format.md`, `logs-format.md`, `knowledge-format.md`) |
| `.claude/ptah/knowledge/` | Ptah's persistent knowledge base — `knowledge.db` (SQLite, sole interface `ptah_knowledge.py`) + `INDEX.md` (auto-regenerated human-readable mirror). Project-wide, not per-spec. See **Knowledge discipline** above |
| `.claude/specs/ptah-<n>-<slug>/` | Per-feature work product (created by `/ptah-spec`) — see **Spec identifiers** above |
| `.claude/reviews/<review-name>/` | Per-review work product (created by `/ptah-review`), separate from the spec pipeline |

Skills link to `RULES.md` and `guides/` in `.claude/ptah/` rather than bundling their own copies — those files are shared by every skill and subagent, so there's one copy to keep current.

---

## Wait for user confirmation

Each command produces an artifact (`SPEC.md`, `DESIGN.md`, `IMPLEMENTATION.md`, etc.) and hands off to the user. Never auto-advance to the next command in the workflow — always wait for the user to review the artifact and explicitly run the next slash command. Every Ptah skill sets `disable-model-invocation: true`, so none of them can be started by the agent on its own — only by the user typing it.
