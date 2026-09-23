# Ptah workflow rules

Cross-cutting rules the agent applies regardless of which slash command is running. These apply to **every** Ptah command (`/spec`, `/design`, `/implement`, `/code-review`, `/fix`, `/document`).

---

## Always read LOGS.md first

When working on any feature, read `LOGS.md` in the relevant spec folder before doing anything else. It is the single source of truth for current state — what's been done, what was decided, what's next. Never skip it, even when "just looking" at one specific file.

---

## Stop and ask, one question at a time

If anything in the spec or design is ambiguous, contradictory, or underspecified, stop and ask the user a targeted question before proceeding. Ask one question at a time when there are several. Do not guess to keep momentum — guessing accumulates into deviations that surface much later.

This applies before:
- Writing any design (`/design`)
- Writing any code (`/implement`)
- Applying any fix (`/fix`)

If everything is clear, skip the clarifying step entirely and proceed.

> **Note on `/fix` modes:** `/fix` supports `auto`, `plan`, and `interactive` modes that control verbosity for routine fixes. The stop-and-ask rule applies in **all three** — if a fix is ambiguous, has side effects beyond scope, requires a design change, or introduces a new dependency, the agent stops and asks. `auto` mode does not suppress this rule.

---

## Why the review is isolated

`/code-review` and `/review` delegate their actual judgment to a dedicated subagent (`ptah-code-reviewer`, `ptah-reviewer` — see `.claude/agents/ptah/`) rather than running the review in the same conversation as the work being reviewed.

A subagent starts with a blank context. It never sees the implementer's live reasoning, discarded approaches, or self-justifications from mid-session — only what's written to `SPEC.md` / `DESIGN.md` / `IMPLEMENTATION.md` / `LOGS.md` and the code itself. That matters: an agent reviewing its own recent work in the same conversation tends to accept its own rationalizations rather than scrutinize them, even when those rationalizations were never written down anywhere a fresh reader could check them.

Two things follow from this, and both commands (and their subagents) are built around them:

- **The reviewer treats `IMPLEMENTATION.md` and `LOGS.md` as claims, not facts.** Its job is to verify what's written against the actual code and against `SPEC.md` / `DESIGN.md`, not to restate what the implementer said happened.
- **The subagent's tools are read-only** (`Read`, `Grep`, `Glob`). It cannot write `CODE-REVIEW.md` / `REVIEW.md` itself — it returns findings as text, and the dispatching command (`/code-review` or `/review`) writes the file. This makes "documentation only, no code changes" an enforced permission boundary rather than just an instruction.

This isolation applies only to the judgment step. `/fix` runs in the main session and trusts the review's findings rather than re-litigating them — applying a fix should follow what the review already decided, not independently re-derive it.

Isolation also determines where the knowledge base gets consulted for reviews — see "Knowledge discipline" below. Since the dispatching commands pass the subagents nothing beyond a folder path, the subagents read `INDEX.md` themselves, the same way they read `SPEC.md` and `IMPLEMENTATION.md` themselves.

---

## Knowledge discipline

Ptah maintains a persistent, project-wide knowledge base — `.claude/ptah/knowledge/knowledge.db` (SQLite) plus its human-readable mirror `INDEX.md` — separate from any single spec's `LOGS.md`. It exists so a gotcha, convention, or dependency quirk discovered once doesn't have to be rediscovered on the next feature, or the one after that. Full schema and CLI contract: [`guides/knowledge-format.md`](./guides/knowledge-format.md).

### Capture is `/learn`-only

Nothing gets written to `knowledge.db` automatically. Workflow commands never call `/learn` on their own behalf, even when they clearly just hit something learn-worthy — capturing is a judgment call the user makes explicitly, which keeps the knowledge base signal instead of noise. If a command notices something that looks worth keeping, it can *suggest* running `/learn` (see `/document`'s final step), but it never runs it unprompted.

### Consulting knowledge is automatic, and cheap by design

Unlike capture, *consulting* the knowledge base is not optional — every workflow command checks it before doing its main work:

- **Main-session commands** (`/design`, `/implement`, `/fix`, `/document`) read `.claude/ptah/knowledge/INDEX.md` directly, early in their own steps, the same way they already read `LOGS.md` first.
- **Isolated review subagents** (`ptah-code-reviewer`, `ptah-reviewer`) read `INDEX.md` themselves, as part of their own Step 1 reading list — *not* something the dispatching `/code-review` or `/review` command passes in, since that would violate the isolation described above.

All of them read only `INDEX.md`, never `knowledge.db` directly — `INDEX.md` is titles, categories, tags, and confidence only, deliberately not full entry bodies, so the consult step stays a cheap scan rather than a token-expensive read. Only `/learn` and `/recall` invoke `ptah_knowledge.py` for the full entry, a search, or a graph traversal — and only when something on the index scan actually looked relevant.

If `INDEX.md` doesn't exist yet (no `/learn` has ever run on this project), every consult step skips silently — this is the expected state for a fresh project, not an error.

### Disjoint from LOGS.md — no cross-citation, either direction

Knowledge entries are never cited in any `LOGS.md` entry, and `LOGS.md` content is never written into `knowledge.db`. If something learned from `INDEX.md` changes a decision mid-session, the decision itself gets a normal `LOGS.md` change entry (per "Logging discipline" below) — the knowledge entry is context that informed the decision, not part of the record of what happened. This mirrors the same reasoning as the isolated-review split: two different systems, two different jobs, no blending them.

### `INDEX.md` is disposable

`INDEX.md` is regenerated in full by `ptah_knowledge.py` on every `/learn` write. It is never hand-edited — any manual edit is silently overwritten on the next write, so there's no reason to make one. If it's ever suspected to have drifted from `knowledge.db` (it shouldn't, since regeneration is automatic), `python3 .claude/ptah/ptah_knowledge.py regenerate-index` rebuilds it without touching any data.

---

## Logging discipline

While working on any spec, append **change entries** to the corresponding `LOGS.md` whenever a meaningful event happens mid-session — not just when a command completes.

### When to log

Log automatically, without asking, on these events:

| Type | Trigger |
|------|---------|
| **Decision** | A choice was made that affects the work (library, pattern, structure, naming convention) |
| **Deviation** | The implementation diverged from the spec or design |
| **Scope change** | Something was added to, removed from, or moved out of scope mid-flow |
| **Blocker** | Stopped to ask the user, or hit something that needs resolving |
| **Correction** | The user pointed out something was wrong, and the agent is redoing it |

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
- Trigger: <user request | agent decision>
- Type: <decision | deviation | scope change | blocker | correction>
- What: <one-line description>
- Why: <reason>
- Impact: <files, decisions, or downstream steps affected; or "none">
```

Append to the same `LOGS.md` as command entries, in chronological order. Change entries are the canonical record of mid-flow events — completion entries reference them ("Deviations: yes — see change entries above") rather than restating them.

The full schema for both command and change entries lives in [`guides/logs-format.md`](./guides/logs-format.md).

---

## Spec identifiers

Every spec folder created by `/spec` is named `ptah-<n>-<slug>`, e.g. `ptah-3-user-login`.

- `<n>` — a sequential integer, unique per project
- `<slug>` — a kebab-case version of the feature name given to `/spec`

### Assigning a number (`/spec` only)

The next number lives in `.claude/ptah/ptah.yml` under `specs.next_id` — this is a plain config value, not something the agent works out by scanning `.claude/specs/`.

When `/spec` creates a new folder:

1. Read `specs.next_id` from `.claude/ptah/ptah.yml`. If the file, or the `specs` section, or the key is missing, treat the next id as `1`.
2. Use that value as `<n>` for the new folder.
3. Immediately after creating the folder, write `specs.next_id: <n + 1>` back to `ptah.yml` — creating the file or the `specs:` section if it didn't exist yet, and leaving any other config (`commands:`, `context_sources:`, etc.) untouched.

The agent never infers the next number from existing folder names. Numbers are never reused, even if a folder is later deleted — the counter only moves forward. If a gap needs reclaiming, that's a manual edit to `specs.next_id`, not something any command does automatically.

(The knowledge base's entry ids follow a related but distinct rule — see "Knowledge discipline" above and `guides/knowledge-format.md`: SQLite's own `AUTOINCREMENT` owns that counter, since there's a real database to keep it in.)

### Resolving an identifier (every other command)

Every command that takes a spec argument — `/design`, `/implement`, `/code-review`, `/fix`, `/document`, `/resume` — accepts any of:

- a bare number: `3`
- a number with the prefix: `ptah-3`
- the full folder name: `ptah-3-user-login`

Resolve the argument in this order:

1. If it matches an existing folder name in `.claude/specs/` exactly, use it.
2. Otherwise, strip a leading `ptah-` if present, take the leading number, and glob `.claude/specs/ptah-<n>-*`. If exactly one folder matches, use it.
3. Otherwise, treat the argument as a literal legacy folder name — `.claude/specs/<argument>/` — for specs that predate this convention.
4. If nothing matches any of the above, stop and tell the user no spec was found for `<argument>`, and suggest running `/status`.

This is a single lookup for one already-existing folder, not a scan across all of them — it's unrelated to how `/spec` assigns new numbers above.

### Displaying identifiers

Whenever a command refers to a spec in output shown to the user — `/resume`'s summary header, or a hand-off message suggesting the next command to run — show **only the number**, e.g. "run `/design 3`". Never surface the slug or full folder name in these contexts.

Two exceptions:
- **`/status` rows** show the full spec name (`ptah-3-user-login`), since the report is a scannable overview meant to be read, not typed. Its `next:` line still uses the bare number, since that's the part you'd actually run.
- **File paths** the user is meant to open and review (e.g. "Review it at `.claude/specs/ptah-3-user-login/SPEC.md`") need the real, full path.

---

## Path conventions

| Location | Purpose |
|----------|---------|
| `.claude/commands/ptah/` | Slash command definitions |
| `.claude/agents/ptah/` | Ptah's subagent definitions — isolated reviewers used by `/code-review` and `/review`. Mirrors `.claude/commands/ptah/`'s convention of namespacing under `ptah/`. See **Why the review is isolated** above |
| `.claude/ptah/` | Ptah's config (`ptah.yml`) and reference docs (`guides/`, `RULES.md`) |
| `.claude/ptah/knowledge/` | Ptah's persistent knowledge base — `knowledge.db` (SQLite, sole interface `ptah_knowledge.py`) + `INDEX.md` (auto-regenerated human-readable mirror). Project-wide, not per-spec. See **Knowledge discipline** above |
| `.claude/specs/ptah-<n>-<slug>/` | Per-feature work product (created by `/spec`) — see **Spec identifiers** above |
| `.claude/reviews/<review-name>/` | Per-review work product (created by `/review`), separate from the spec pipeline |

---

## Wait for user confirmation

Each command produces an artifact (`SPEC.md`, `DESIGN.md`, `IMPLEMENTATION.md`, etc.) and hands off to the user. Never auto-advance to the next command in the workflow — always wait for the user to review the artifact and explicitly run the next slash command.
