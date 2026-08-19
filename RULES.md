# Ptah workflow rules

Cross-cutting rules the agent applies regardless of which slash command is running. These apply to **every** Ptah command (`/spec`, `/design`, `/implement`, `/code-review`, `/fix`, `/test`, `/document`).

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
- Writing any test scenario or YAML (`/test`)

If everything is clear, skip the clarifying step entirely and proceed.

> **Note on `/fix` modes:** `/fix` supports `auto`, `plan`, and `interactive` modes that control verbosity for routine fixes. The stop-and-ask rule applies in **all three** — if a fix is ambiguous, has side effects beyond scope, requires a design change, or introduces a new dependency, the agent stops and asks. `auto` mode does not suppress this rule.

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

## Testing is optional

The `/test` step is opt-in per project. It's controlled by `commands.test.enabled` in `.claude/ptah/ptah.yml`, and **defaults to `false`** — testing is off unless a project explicitly enables it.

When testing is **disabled** (the default):
- `/test` refuses to run and tells the user how to enable it
- `/code-review` and `/fix` route their hand-off to `/document` instead of `/test`
- `/document` does not consult `TEST.md` when checking whether a feature is complete
- `/status` and `/resume` treat `/document` as the next step after `/fix` (or after `/code-review` with no issues)

When testing is **enabled**, the workflow runs the full track including `/test` exactly as documented in each command file.

To enable testing on a project, set this in `.claude/ptah/ptah.yml`:

```yaml
commands:
  test:
    enabled: true
```

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

### Resolving an identifier (every other command)

Every command that takes a spec argument — `/design`, `/implement`, `/code-review`, `/fix`, `/test`, `/document`, `/resume` — accepts any of:

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

Whenever a command refers to a spec in output shown to the user — `/status` rows, `/resume`'s summary header, or a hand-off message suggesting the next command to run — show **only the number**, e.g. "run `/design 3`". Never surface the slug or full folder name in these contexts.

The one exception is a file path the user is meant to open and review (e.g. "Review it at `.claude/specs/ptah-3-user-login/SPEC.md`") — those need the real, full path.

---

## Path conventions

| Location | Purpose |
|----------|---------|
| `.claude/commands/ptah/` | Slash command definitions |
| `.claude/ptah/` | Ptah's config (`ptah.yml`) and reference docs (`guides/`, `RULES.md`) |
| `.claude/specs/ptah-<n>-<slug>/` | Per-feature work product (created by `/spec`) — see **Spec identifiers** above |
| `.maestro/specs/ptah-<n>-<slug>/` | Maestro test flows (separate from Ptah), mirrors the spec folder name |

---

## Wait for user confirmation

Each command produces an artifact (`SPEC.md`, `DESIGN.md`, `IMPLEMENTATION.md`, etc.) and hands off to the user. Never auto-advance to the next command in the workflow — always wait for the user to review the artifact and explicitly run the next slash command.
